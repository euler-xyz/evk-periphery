// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {TransceiverStructs} from "native-token-transfers/libraries/TransceiverStructs.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";

contract NttManagerDeployer is ScriptUtils {
    function run() public broadcast returns (address manager) {
        string memory inputScriptFileName = "14_NttManager_input.json";
        string memory outputScriptFileName = "14_NttManager_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address token = vm.parseJsonAddress(json, ".token");
        bool isLockingMode = vm.parseJsonBool(json, ".isLockingMode");
        uint16 chainId = uint16(vm.parseJsonUint(json, ".chainId"));
        uint64 rateLimitDuration = uint64(vm.parseJsonUint(json, ".rateLimitDuration"));
        bool skipRateLimiting = vm.parseJsonBool(json, ".skipRateLimiting");

        manager = execute(token, isLockingMode, chainId, rateLimitDuration, skipRateLimiting);

        string memory object;
        object = vm.serializeAddress("ntt", "manager", manager);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address token, bool isLockingMode, uint16 chainId, uint64 rateLimitDuration, bool skipRateLimiting)
        public
        broadcast
        returns (address manager)
    {
        manager = execute(token, isLockingMode, chainId, rateLimitDuration, skipRateLimiting);
    }

    function execute(address token, bool isLockingMode, uint16 chainId, uint64 rateLimitDuration, bool skipRateLimiting)
        public
        returns (address manager)
    {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-ntt/NttManager.sol/NttManager.json"),
            abi.encode(
                token,
                isLockingMode ? IManagerBase.Mode.LOCKING : IManagerBase.Mode.BURNING,
                chainId,
                rateLimitDuration,
                skipRateLimiting
            )
        );
        assembly {
            manager := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        manager = address(new ERC1967Proxy(manager, ""));
        NttManager(manager).initialize();
    }
}

contract WormholeTransceiverDeployer is ScriptUtils {
    function run() public broadcast returns (address transceiver) {
        string memory inputScriptFileName = "14_WormholeTransceiver_input.json";
        string memory outputScriptFileName = "14_WormholeTransceiver_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address nttManager = vm.parseJsonAddress(json, ".nttManager");
        address wormholeCoreBridge = vm.parseJsonAddress(json, ".wormholeCoreBridge");
        address wormholeRelayer = vm.parseJsonAddress(json, ".wormholeRelayer");
        address specialRelayer = vm.parseJsonAddress(json, ".specialRelayer");
        uint8 consistencyLevel = uint8(vm.parseJsonUint(json, ".consistencyLevel"));
        uint256 gasLimit = vm.parseJsonUint(json, ".gasLimit");

        transceiver =
            execute(nttManager, wormholeCoreBridge, wormholeRelayer, specialRelayer, consistencyLevel, gasLimit);

        string memory object;
        object = vm.serializeAddress("ntt", "transceiver", transceiver);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address nttManager,
        address wormholeCoreBridge,
        address wormholeRelayer,
        address specialRelayer,
        uint8 consistencyLevel,
        uint256 gasLimit
    ) public broadcast returns (address transceiver) {
        transceiver =
            execute(nttManager, wormholeCoreBridge, wormholeRelayer, specialRelayer, consistencyLevel, gasLimit);
    }

    function execute(
        address nttManager,
        address wormholeCoreBridge,
        address wormholeRelayer,
        address specialRelayer,
        uint8 consistencyLevel,
        uint256 gasLimit
    ) public returns (address transceiver) {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-ntt/WormholeTransceiver.sol/WormholeTransceiver.json"),
            abi.encode(nttManager, wormholeCoreBridge, wormholeRelayer, specialRelayer, consistencyLevel, gasLimit)
        );
        assembly {
            transceiver := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        transceiver = address(new ERC1967Proxy(transceiver, ""));
        WormholeTransceiver(transceiver).initialize();
    }
}
