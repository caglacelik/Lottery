// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

pragma solidity ^0.8.20;

contract DeployLottery is Script {
    HelperConfig public helperConfig;
    Lottery public lottery;

    function run() external returns (Lottery, HelperConfig) {
        helperConfig = new HelperConfig();
        (
            uint64 _subscriptionId,
            address _vrfCoordinator,
            uint256 _fee,
            uint256 _interval,
            bytes32 _keyHash,
            address _link,
            uint256 _deployerKey
        ) = helperConfig.currentConfig();

        if (_subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            _subscriptionId = createSubscription.createSubscription(
                _vrfCoordinator,
                _deployerKey
            );
        }

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            _vrfCoordinator,
            _subscriptionId,
            _link,
            _deployerKey
        );

        vm.startBroadcast();
        lottery = new Lottery(
            _subscriptionId,
            _vrfCoordinator,
            _fee,
            _interval,
            _keyHash
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(lottery),
            _vrfCoordinator,
            _subscriptionId,
            _deployerKey
        );

        return (lottery, helperConfig);
    }
}
