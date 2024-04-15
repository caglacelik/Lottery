// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {Lottery} from "../src/Lottery.sol";

contract CreateSubscription is Script {
    HelperConfig public helperConfig;

    function createSubscriptionUserConfig()
        public
        returns (uint64 subscriptionId)
    {
        helperConfig = new HelperConfig();
        (, address _vrfCoordinator, , , , , uint256 _deployerKey) = helperConfig
            .currentConfig();
        return createSubscription(_vrfCoordinator, _deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 _deployerKey
    ) public returns (uint64 subscriptionId) {
        vm.startBroadcast(_deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUserConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant AMOUNT = 1 ether;
    HelperConfig helperConfig;

    function fundSubscriptionUserConfig() public {
        helperConfig = new HelperConfig();
        (
            uint64 _subId,
            address _vrfCoordinator,
            ,
            ,
            ,
            address _link,
            uint256 _deployerKey
        ) = helperConfig.currentConfig();
        fundSubscription(_vrfCoordinator, _subId, _link, _deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 _deployerKey
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(_deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUserConfig();
    }
}

contract AddConsumer is Script {
    HelperConfig helperConfig;

    function addConsumer(
        address _lottery,
        address _vrfCoordinator,
        uint64 _subId,
        uint256 _deployerKey
    ) public {
        vm.startBroadcast(_deployerKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(_subId, _lottery);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address lottery) public {
        helperConfig = new HelperConfig();
        (
            uint64 subId,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.currentConfig();
        addConsumer(lottery, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerUsingConfig(lottery);
    }
}
