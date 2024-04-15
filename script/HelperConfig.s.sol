// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import "forge-std/Vm.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint64 _subscriptionId;
        address _vrfCoordinator;
        uint256 _fee;
        uint256 _interval;
        bytes32 _keyHash;
        address _link;
        uint256 _deployerKey;
    }

    NetworkConfig public currentConfig;

    uint256 public constant ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            currentConfig = getSepholiaConfig();
        }
        if (block.chainid == 421614) {
            currentConfig = getArbitrumSepholiaConfig();
        } else {
            currentConfig = getOrCreateAnvilConfig();
        }
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (currentConfig._vrfCoordinator != address(0)) {
            return currentConfig;
        }

        uint96 baseFee = 0.0001 ether; // 0.0001 LINK
        uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        vm.stopBroadcast();
        LinkToken linkToken = new LinkToken();
        return
            NetworkConfig({
                _subscriptionId: 0,
                _keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                _vrfCoordinator: address(vrfCoordinatorMock),
                _fee: 0.0001 ether,
                _interval: 30,
                _link: address(linkToken),
                _deployerKey: ANVIL_KEY
            });
    }

    function getSepholiaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                _subscriptionId: 0,
                _keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                _vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                _fee: 0.0001 ether,
                _interval: 30,
                _link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                _deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
            });
    }

    function getArbitrumSepholiaConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                _subscriptionId: 0,
                _keyHash: 0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414,
                _vrfCoordinator: 0x50d47e4142598E3411aA864e08a44284e471AC6f,
                _fee: 0.0001 ether,
                _interval: 30, // in seconds
                _link: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
                _deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
            });
    }
}
