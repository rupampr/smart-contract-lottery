//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title A sample Raffle contract
 * @author Rupam Pradhan
 * @notice This contract is a sample contract for a raffle system
 * @dev Implements chainlink VRF 
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SentMoreTOEnterRaffle();
    error Raffle__Transferfail();
    error Raffle__NeedMoreTime();
    error Raffle__CalculatingWinner();
    error Raffle__UpKeepNotNeeded(uint256 balance,uint256 length,uint256 raffleState);
    /* Type declaration */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint32 private constant NUMBER_OF_WORDS = 3;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] public s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_rafflestate;
    
    /* events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee,uint256 interval, address vrfCoordinator,bytes32 gaslane,uint256 subcriptionId,uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gaslane;
        i_subscriptionId = subcriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
    }
    function enterRaffle() public payable {
        // require(msg.value == i_entranceFee, "Incorrect entrance fee");
        // require(msg.value == i_entranceFee, Raffle__SentMoreTOEnterRaffle());
        if(msg.value < i_entranceFee) {
           revert Raffle__SentMoreTOEnterRaffle();
        }
        if(s_rafflestate != RaffleState.OPEN){
            revert Raffle__CalculatingWinner();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }
 
    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (s_rafflestate == RaffleState.OPEN);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, bytes("0x0"));
    }
    // CEI pattern - Check Effect Interaction
    function performUpkeep(bytes calldata /* performData */) public  {
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance,s_players.length,uint256(s_rafflestate));
        } 
        s_rafflestate = RaffleState.CALCULATING;
        // get our random number VRF2.5 
        VRFV2PlusClient.RandomWordsRequest memory request = 
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
            uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
            emit RequestedRaffleWinner(requestId);
    }
     function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override{
        //Checks
        // require or revert statement
        //Effects
        uint256 IndexOFWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[IndexOFWinner];
        s_recentWinner = recentWinner; //storing recent winner
        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner); 
        //Interaction
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if(!success) revert Raffle__Transferfail();
        
     }
    /** Getter function */
    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }
    function getInterval() external view returns (uint256){
        return i_interval;
    }
    function getRaffleState() external view returns (RaffleState){
        return s_rafflestate;
    }
    function getPlayers(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}