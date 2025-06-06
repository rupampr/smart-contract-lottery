//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/Raffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Helperconfig} from "../../script/Helperconfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
contract RaffleTest is Test {
    DeployRaffle public deployRaffle;
    Raffle public raffle;
    Helperconfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint256 subcriptionId;
    uint32 callbackGasLimit;

    /* events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        Helperconfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;   
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gaslane = config.gaslane;
        subcriptionId = config.subcriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
    }
    function testRaffleInitInOpenState() public view {
        //Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    function testRaffleRevertWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__SentMoreTOEnterRaffle.selector);
        raffle.enterRaffle();
        
    }
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value:entranceFee}();
        address playerRecorded = raffle.getPlayers(0);
        //Assert
        assert(playerRecorded == PLAYER);
    }
    function testEnteringRaffleEmitEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act/Assert
        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
    }
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__CalculatingWinner.selector);
        raffle.enterRaffle{value:entranceFee}();
    }
    /*    checkupkeep test      */
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        //Act 
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded == false);
    }
    function testCheckUpKeepReturnsFalseIfIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded == false);
    }
    /*    performupkeep test      */
    function testPerformUpKeepCanOnlyRunWhenIfCheckUpKeepISTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        //Act/Assert
        raffle.performUpkeep("");
    }
    function testPerformUpKeepRevertsWhenIfCheckUpKeepISFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;
        //Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }
    //what if we need data from emitted events
    function testPerformUpKeepUpdateRaffleStateAndEmitsRequestId() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);

        //Act 
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId)> 0 );
        assert(uint256(raffleState)==1);
    }
    /* fullfillRandomWords */
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId,address(raffle));
    }
    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        uint256 addtionalEntries = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for(uint256 i = startingIndex;i<(startingIndex+addtionalEntries);i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value:entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));

        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTImeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee*(addtionalEntries+1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == (winnerStartingBalance+prize));
        assert(endingTImeStamp > startingTimeStamp );
    }
}
