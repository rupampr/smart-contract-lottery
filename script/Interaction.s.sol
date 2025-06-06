// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Script,console} from "forge-std/Script.sol";
import {Helperconfig,CodeConstants} from "./Helperconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubcription is Script{
    function run() external {
      createSubcriptionUsingConfig();  
    }
    function createSubcriptionUsingConfig() public returns (uint256,address){
        Helperconfig helperConfig = new Helperconfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubcription(vrfCoordinator,account);
        return(subId,vrfCoordinator);
    }
    function createSubcription(address vrfCoordinator,address account) public returns (uint256,address){
        console.log("Creating subcription on chain Id",block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subcription created with id",subId);
        console.log("Please update the subcription id in the Helperconfig contract");
        return (subId,vrfCoordinator);
    }
}
    contract FundSubcription is Script,CodeConstants{
      uint256 public constant FUND_AMOUNT = 300 ether;
      function run() external {
        fundSubcriptionUsingConfig();
      }
      function fundSubcriptionUsingConfig() public {
        Helperconfig helperConfig = new Helperconfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subcriptionId = helperConfig.getConfig().subcriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubcription(vrfCoordinator,subcriptionId,linkToken,account);
      }
      function fundSubcription(address vrfCoordinator,uint256 subcriptionId,address linkToken,address account) public {
        console.log("Funding subcription :",subcriptionId);
        console.log("Using vrfCoordinator :",vrfCoordinator);
        console.log("On chain Id",block.chainid);
        if(block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subcriptionId,FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else{
          vm.startBroadcast(account);
          LinkToken(linkToken).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subcriptionId));
          vm.stopBroadcast();

        }
      }
}
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        Helperconfig helperConfig = new Helperconfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subcriptionId = helperConfig.getConfig().subcriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed,vrfCoordinator,subcriptionId,account);
    }
    function addConsumer(address contractToAddToVrf,address vrfCoordinator,uint256 subcriptionId,address account) public {
        console.log("Adding consumer to contract :",contractToAddToVrf);
        console.log("To vrfCoordinator :",vrfCoordinator);
        console.log("On chain Id",block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subcriptionId,contractToAddToVrf);
        vm.stopBroadcast();
    }
    
    function run() external {
        address mostRecentlyDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedContract);
    }
    
}
