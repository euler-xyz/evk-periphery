// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapImplementationDeployer is ScriptUtils {
    function run() public broadcast returns (address protocolFeeConfig, address eulerSwapImplementation) {
        string memory inputScriptFileName = "21_EulerSwapImplementation_input.json";
        string memory outputScriptFileName = "21_EulerSwapImplementation_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address protocolFeeConfigAdmin = vm.parseJsonAddress(json, ".protocolFeeConfigAdmin");
        address poolManager = vm.parseJsonAddress(json, ".poolManager");

        (protocolFeeConfig, eulerSwapImplementation) = execute(evc, protocolFeeConfigAdmin, poolManager);

        string memory object;
        object = vm.serializeAddress("implementation", "protocolFeeConfig", protocolFeeConfig);
        object = vm.serializeAddress("implementation", "eulerSwapImplementation", eulerSwapImplementation);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address protocolFeeConfigAdmin, address poolManager)
        public
        broadcast
        returns (address protocolFeeConfig, address eulerSwapImplementation)
    {
        (protocolFeeConfig, eulerSwapImplementation) = execute(evc, protocolFeeConfigAdmin, poolManager);
    }

    function execute(address evc, address protocolFeeConfigAdmin, address poolManager)
        public
        returns (address protocolFeeConfig, address eulerSwapImplementation)
    {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwapProtocolFeeConfig.sol/EulerSwapProtocolFeeConfig.json"),
            abi.encode(evc, protocolFeeConfigAdmin)
        );
        assembly {
            protocolFeeConfig := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwapManagement.sol/EulerSwapManagement.json"), abi.encode(evc)
        );
        address managementImplementation;
        assembly {
            managementImplementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwap.sol/EulerSwap.json"),
            abi.encode(evc, protocolFeeConfig, poolManager, managementImplementation)
        );
        assembly {
            eulerSwapImplementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
