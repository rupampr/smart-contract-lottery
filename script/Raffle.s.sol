//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {Helperconfig} from "./Helperconfig.s.sol";
import {CreateSubcription,FundSubcription,AddConsumer} from "./Interaction.s.sol";
contract DeployRaffle is Script {
    function deployContract() external returns (Raffle,Helperconfig){
        Helperconfig helperConfig = new Helperconfig();
        Helperconfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subcriptionId == 0){
            //create subcription
            CreateSubcription subcription = new CreateSubcription();
            (config.subcriptionId,config.vrfCoordinator) = subcription.createSubcription(config.vrfCoordinator,config.account);
            //fund it
            FundSubcription fundSubcription = new FundSubcription();
            fundSubcription.fundSubcription(config.vrfCoordinator,config.subcriptionId,config.link,config.account);
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(config.entranceFee,config.interval,config.vrfCoordinator,config.gaslane,config.subcriptionId,config.callbackGasLimit);
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle),config.vrfCoordinator,config.subcriptionId,config.account);
        return (raffle,helperConfig);
    }
}