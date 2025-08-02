// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from 'script/Interactions.s.sol';

contract DeployRaffle is Script {
    function run() public {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfigContract = new HelperConfig();
        // when local: deploy mocks, get local config
        // when sepolia: get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfigContract.getConfig();

        if (config.subscriptionId == 0) {
            // create subscription:
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, ) = createSubscription.createSubscription(config.vrfCoordinator);

            // fund subscription:
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);
        }

        vm.startBroadcast();
        Raffle raffleContract = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // don't need to broadcast this, because in addConsumer.addConsumer already is broadcasting
        addConsumer.addConsumer(address(raffleContract), config.vrfCoordinator, config.subscriptionId);

        return (raffleContract, helperConfigContract);
    }
}
