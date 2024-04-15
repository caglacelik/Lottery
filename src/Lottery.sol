// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFConsumerBaseV2} from "@chainlink/contracts/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/interfaces/VRFCoordinatorV2Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyMock} from "@openzeppelin/contracts/mocks/ReentrancyMock.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/interfaces/AutomationCompatibleInterface.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Lottery Contract
 * @author CC
 * @notice This contract is for creating a lottery
 * @dev Uses Chainlink VRF
 */
contract Lottery is
    AutomationCompatibleInterface,
    VRFConsumerBaseV2,
    Ownable,
    ReentrancyMock
{
    // Errors
    error Lottery__DidNotPayCorrectEntryBalance(address player, uint256 value);
    error Lottery__FailedSendingValue(address player);
    error Lottery__AlreadyStarted();
    error Lottery__NothingToClaim();
    error Lottery__UpkeepNotNeeded(
        uint256 currentReward,
        uint256 numPlayers,
        uint256 state
    );

    // @dev Chainlink's State Variables
    uint16 private constant NUMBER_OF_WORDS = 1;
    uint16 private constant REQUEST_CONFORMATIONS = 3;
    uint32 private constant CALLBASK_GAS_LIMIT = 500000;
    uint64 private immutable s_subscriptionId;
    bytes32 private immutable i_keyHash;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    // @dev Lottery's State Variables
    uint256 private s_currentLotteryId;
    uint256 private s_currentReward;
    uint256 private immutable i_fee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastStartTime;

    // @dev lotId to winner's address mapping
    mapping(uint256 => address) private winners;

    // @dev winner's address to s_currentReward mapping
    mapping(address => uint256) private rewards;

    // @dev s_currentLotteryId to players mapping
    mapping(uint256 => address payable[]) private players;

    enum LotteryState {
        WAITING_FOR_START,
        STARTED
    }

    LotteryState private s_currentState;

    // @dev Events
    event LotteryStarted(uint256 indexed lotId);
    event PlayerJoined(uint256 indexed lotId, address indexed player);
    event LotteryEnded(
        uint256 indexed lotId,
        address indexed winner,
        uint256 s_currentReward,
        uint256 startTime,
        uint256 endTime
    );
    event RewardClaimed(address indexed winner, uint256 reward);

    // @dev Modifiers
    modifier checkStarted() {
        if (s_currentState != LotteryState.STARTED) {
            revert Lottery__AlreadyStarted();
        }
        _;
    }

    modifier claim(uint256 lotId) {
        if (winners[lotId] != msg.sender) {
            revert Lottery__NothingToClaim();
        }
        _;
        winners[lotId] = msg.sender;
        rewards[msg.sender] = 0;
    }

    constructor(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        uint256 _fee,
        uint256 _interval,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) Ownable(msg.sender) ReentrancyMock() {
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        s_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_fee = _fee;
        i_interval = _interval;
    }

    receive() external payable {
        console.log("receive called");
        joinLottery();
    }

    fallback() external payable {
        console.log("fallback called");
        joinLottery();
    }

    function startLottery() external onlyOwner {
        s_currentState = LotteryState.STARTED;
        s_currentLotteryId += 1;

        s_lastStartTime = block.timestamp;
        emit LotteryStarted(s_currentLotteryId);
    }

    function claimReward(uint256 lotId) external nonReentrant claim(lotId) {
        uint256 reward = rewards[msg.sender];
        (bool sent, ) = payable(msg.sender).call{value: reward}("");

        if (!sent) {
            revert Lottery__FailedSendingValue(msg.sender);
        }

        rewards[msg.sender] = 0;
        emit RewardClaimed(msg.sender, reward);
    }

    function getCurrentReward() external view returns (uint256) {
        return s_currentReward;
    }

    function getFee() external view returns (uint256) {
        return i_fee;
    }

    function getCurrentState() external view returns (LotteryState) {
        return s_currentState;
    }

    function getCurrentLotId() external view returns (uint256) {
        return s_currentLotteryId;
    }

    function getLastStartTime() external view returns (uint256) {
        return s_lastStartTime;
    }

    function checkWinner(uint256 lotId) external view returns (bool) {
        return winners[lotId] == msg.sender;
    }

    function getWinner(uint256 lotId) external view returns (address) {
        return winners[lotId];
    }

    function getReward() external view returns (uint256) {
        return rewards[msg.sender];
    }

    function getPlayers(
        uint256 lotId
    ) external view returns (address payable[] memory) {
        return players[lotId];
    }

    function joinLottery() public payable checkStarted nonReentrant {
        if (msg.value != i_fee) {
            revert Lottery__DidNotPayCorrectEntryBalance(msg.sender, msg.value);
        }
        s_currentReward += msg.value;
        players[s_currentLotteryId].push(payable(msg.sender));

        emit PlayerJoined(s_currentLotteryId, msg.sender);
    }

    function checkUpkeep(
        bytes memory
    ) public view override returns (bool upkeepNeeded, bytes memory) {
        bool isOpen = LotteryState.STARTED == s_currentState;
        bool timePassed = ((block.timestamp - s_lastStartTime) > i_interval);
        bool hasPlayers = players[s_currentLotteryId].length > 0;
        bool hasBalance = s_currentReward > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                s_currentReward,
                players[s_currentLotteryId].length,
                uint256(s_currentState)
            );
        }
        i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            s_subscriptionId,
            REQUEST_CONFORMATIONS,
            CALLBASK_GAS_LIMIT,
            NUMBER_OF_WORDS
        );
    }

    function fulfillRandomWords(
        uint256,
        /* requestId */ uint256[] memory _randomWords
    ) internal override nonReentrant checkStarted {
        uint256 index = _randomWords[0] % players[s_currentLotteryId].length;
        address winner = players[s_currentLotteryId][index];

        winners[s_currentLotteryId] = winner;
        rewards[winner] = s_currentReward;

        emit LotteryEnded(
            s_currentLotteryId,
            winner,
            s_currentReward,
            s_lastStartTime,
            s_lastStartTime + i_interval
        );

        s_currentReward = 0;
        s_currentState = LotteryState.WAITING_FOR_START;
    }
}
