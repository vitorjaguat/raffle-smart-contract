// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {Raffle} from 'src/Raffle.sol';
import {HelperConfig} from 'script/HelperConfig.s.sol';

contract DeployRaffle is Script {
    function run() public {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfigContract = new HelperConfig();
        // when local: deploy mocks, get local config
        // when sepolia: get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfigContract.getConfig();

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
        return (raffleContract, helperConfigContract);

    }
}