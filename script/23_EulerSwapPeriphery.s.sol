// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapPeripheryDeployer is ScriptUtils {
    function run() public broadcast returns (address periphery) {
        string memory outputScriptFileName = "23_EulerSwapPeriphery_output.json";

        periphery = execute();

        string memory object;
        object = vm.serializeAddress("periphery", "eulerSwapPeriphery", periphery);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy() public broadcast returns (address periphery) {
        periphery = execute();
    }

    function execute() public returns (address periphery) {
        bytes memory bytecode =
            abi.encodePacked(vm.getCode("out-euler-swap/EulerSwapPeriphery.sol/EulerSwapPeriphery.json"));
        assembly {
            periphery := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
