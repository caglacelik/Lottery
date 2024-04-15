// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";

contract DeployLotteryTest is Test {
    uint64 _subscriptionId;
    uint256 _fee;
    uint256 _interval;
    bytes32 _keyHash;
    address _vrfCoordinator;
    address _link;
    uint256 _deployerKey;

    Lottery lottery;
    HelperConfig helperConfig;
    DeployLottery deployer;

    event SubscriptionFunded(
        uint64 indexed subId,
        uint256 oldBalance,
        uint256 newBalance
    );

    function setUp() external {
        deployer = new DeployLottery();

        (lottery, helperConfig) = deployer.run();
        (
            _subscriptionId,
            _vrfCoordinator,
            _fee,
            _interval,
            _keyHash,
            _link,
            _deployerKey
        ) = helperConfig.currentConfig();
    }

    function test_deployLottery() external view {
        assert(address(lottery) != address(0));
        assert(address(helperConfig) != address(0));
        assert(_fee == 0.0001 ether);
        assert(
            _keyHash ==
                0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
        );
    }
}
