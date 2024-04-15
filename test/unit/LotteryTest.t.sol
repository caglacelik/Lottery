// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    uint64 _subscriptionId;
    uint256 _fee;
    uint256 _interval;
    bytes32 _keyHash;
    address _vrfCoordinator;
    address _link;
    uint256 _deployerKey;

    address[] public players;

    address public OWNER;
    uint256 public constant STARTING_OWNER_BALANCE = 2 ether;

    event LotteryStarted(uint256 indexed lotId);
    event PlayerJoined(uint256 indexed lotId, address indexed player);
    event LotteryEnded(
        uint256 indexed lotId,
        address indexed winner,
        uint256 s_currentReward,
        uint256 startTime,
        uint256 endTime
    );
    event RewardClaimed(address winner, uint256 s_currentReward);

    modifier lotteryStarted() {
        vm.recordLogs();
        vm.prank(OWNER);
        lottery.startLottery();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = logs[0].topics[0];
        bytes32 lotId = logs[0].topics[1];

        assertEq(sig, keccak256("LotteryStarted(uint256)"));
        assertEq(lottery.getCurrentLotId(), uint256(lotId));
        _;
    }

    modifier joinedLottery() {
        for (uint256 i = 0; i < 15; i++) {
            vm.expectEmit(true, true, false, false, address(lottery));
            emit PlayerJoined(lottery.getCurrentLotId(), players[i]);

            vm.prank(players[i]);
            lottery.joinLottery{value: _fee}();
        }
        assertEq((lottery.getPlayers(lottery.getCurrentLotId())).length, 15);
        _;
    }

    modifier timePassed() {
        uint256 startTime = block.timestamp;
        uint256 blockNum = block.number;

        vm.warp(startTime + _interval + 1);
        vm.roll(blockNum + 1);
        _;
    }

    modifier pickedWinner() {
        lottery.performUpkeep("");
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            1,
            address(lottery)
        );
        _;
    }

    modifier skipTest() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
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

        OWNER = lottery.owner();
        vm.deal(OWNER, STARTING_OWNER_BALANCE);

        for (uint256 i = 0; i < 15; i++) {
            players.push(makeAddr(string.concat("player", vm.toString(i))));
            vm.deal(players[i], 1 ether);
        }

        for (uint256 i = 0; i < players.length; i++) {
            uint256 codeSize;
            address playerAddr = players[i];
            assembly {
                codeSize := extcodesize(playerAddr)
            }

            if (codeSize == 0) {
                // console.log("Address", playerAddr, " EOA");
                return;
            }
        }
    }

    function test_initializesState() external view {
        assert(
            lottery.getCurrentState() == Lottery.LotteryState.WAITING_FOR_START
        );
    }

    function test_startsLottery() public lotteryStarted {
        assertEq(lottery.getLastStartTime(), block.timestamp);
        assertEq(lottery.getCurrentLotId(), 1);
        assertEq(lottery.getCurrentReward(), 0);
        assertEq(
            uint256(lottery.getCurrentState()),
            uint256(Lottery.LotteryState.STARTED)
        );
    }

    function test_RevertsWhenLotteryIsStarted() external {
        vm.prank(players[0]);
        vm.expectRevert(abi.encodeWithSignature("Lottery__AlreadyStarted()"));
        lottery.joinLottery{value: 0.0001 ether}();
    }

    function test_RevertsWhenYouAreNotAnOwner() external {
        vm.prank(players[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                players[1]
            )
        );
        lottery.startLottery();
    }

    function test_RevertsWhenYouDontPayTheCorrectFee() external lotteryStarted {
        vm.prank(players[4]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__DidNotPayCorrectEntryBalance.selector,
                players[4],
                1 ether
            )
        );
        lottery.joinLottery{value: 1 ether}();
        vm.prank(players[3]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__DidNotPayCorrectEntryBalance.selector,
                players[3],
                0
            )
        );
        lottery.joinLottery();
    }

    function test_NewPlayersJoinedToLottery() external lotteryStarted {
        vm.recordLogs();
        vm.prank(players[0]);
        lottery.joinLottery{value: _fee}();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);

        bytes32 sig = logs[0].topics[0];
        bytes32 lotId = logs[0].topics[1];
        bytes32 playerAddress = logs[0].topics[2];

        // PlayerJoined(s_currentLotteryId, msg.sender);
        assertEq(sig, keccak256("PlayerJoined(uint256,address)"));
        assertEq(uint256(lotId), lottery.getCurrentLotId());
        assertEq(playerAddress, bytes32(abi.encode(players[0])));
    }

    function test_CheckUpKeepReturnsFalseWhenEhoughTimeIsNotPassed()
        external
        lotteryStarted
        joinedLottery
    {
        uint256 startTime = lottery.getLastStartTime();
        vm.prank(OWNER);
        vm.warp(startTime);
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_CheckUpKeepReturnsFalseWhenRewardIsZero()
        external
        lotteryStarted
        timePassed
    {
        uint256 startTime = lottery.getLastStartTime();
        assert(block.timestamp > startTime + _interval);

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_CheckUpKeepReturnsTrue()
        external
        lotteryStarted
        joinedLottery
        timePassed
    {
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        external
        lotteryStarted
        joinedLottery
        timePassed
    {
        lottery.performUpkeep("");
    }

    function test_PerformUpkeepRevertsWhenCheckUpkeepIsFalse() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotNeeded.selector,
                0, // current reward
                0, // number of players
                0 // current state
            )
        );
        lottery.performUpkeep("");
    }

    function test_FullfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) external skipTest lotteryStarted joinedLottery timePassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function test_RevertsWithNothingToClaim()
        external
        lotteryStarted
        timePassed
    {
        vm.prank(players[5]);
        vm.expectRevert(abi.encodeWithSignature("Lottery__NothingToClaim()"));
        lottery.claimReward(4);
    }

    function test_FullfillRandomWordsPicksAWinnerAndClaimedReward()
        external
        skipTest
        lotteryStarted
        joinedLottery
        timePassed
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 sig = logs[0].topics[0];
        (
            uint256 reqId,
            ,
            uint16 minimumRequestConfirmations,
            ,
            uint32 numWords
        ) = abi.decode(
                logs[0].data,
                (uint256, uint256, uint16, uint32, uint32)
            );
        bytes32 lotteryAddr = bytes32(logs[0].topics[3]);

        assertEq(
            sig,
            keccak256(
                "RandomWordsRequested(bytes32,uint256,uint256,uint64,uint16,uint32,uint32,address)"
            )
        );
        assertEq(reqId, 1);
        assertEq(minimumRequestConfirmations, 3);
        assertEq(numWords, 1);

        assertEq(lotteryAddr, bytes32(abi.encode(address(lottery))));

        vm.recordLogs();
        VRFCoordinatorV2Mock(_vrfCoordinator).fulfillRandomWords(
            1,
            address(lottery)
        );

        logs = vm.getRecordedLogs();

        sig = logs[0].topics[0];
        assertEq(
            sig,
            keccak256("LotteryEnded(uint256,address,uint256,uint256,uint256)")
        );

        uint256 lotId = uint256(logs[0].topics[1]);

        assertEq(lotId, lottery.getCurrentLotId());
        assertEq(uint256(lottery.getCurrentState()), 0);
        assertEq(lottery.getCurrentReward(), 0);

        bytes32 winner = logs[0].topics[2];
        address expectedWinner = lottery.getWinner(lottery.getCurrentLotId());
        assertEq(bytes32(abi.encode(expectedWinner)), winner);

        (uint256 s_currentReward, uint256 startTime, uint256 endTime) = abi
            .decode(logs[0].data, (uint256, uint256, uint256));

        vm.startPrank(expectedWinner);
        assertEq(s_currentReward, lottery.getReward());
        assertEq(startTime, lottery.getLastStartTime());
        assertEq(endTime, startTime + _interval);
        lottery.claimReward(lotId);
        vm.stopPrank();

        assertEq(expectedWinner.balance, (_fee * 14) + 1e18);
        assertEq(lottery.getReward(), 0);
        assertEq(address(lottery).balance, 0);
    }

    function test_JoinedLotteryViaFallback() external lotteryStarted {
        vm.prank(players[10]);

        (bool sent, ) = address(lottery).call{value: _fee}("data");

        assert(sent);
        assert(lottery.getPlayers(lottery.getCurrentLotId()).length == 1);

        address PLAYER = lottery.getPlayers(lottery.getCurrentLotId())[0];
        assert(PLAYER == players[10]);
    }

    function test_JoinedLotteryViaReceive() external lotteryStarted {
        vm.prank(players[5]);
        (bool sent, ) = address(lottery).call{value: _fee}("");
        assert(sent);
        assert(lottery.getPlayers(lottery.getCurrentLotId()).length == 1);

        address PLAYER = lottery.getPlayers(lottery.getCurrentLotId())[0];
        assert(PLAYER == players[5]);
    }
}
