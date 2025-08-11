// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapImplementationDeployer is ScriptUtils {
    function run() public broadcast returns (address implementation) {
        string memory inputScriptFileName = "22_EulerSwapImplementation_input.json";
        string memory outputScriptFileName = "22_EulerSwapImplementation_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address poolManager = vm.parseJsonAddress(json, ".poolManager");

        implementation = execute(evc, poolManager);

        string memory object;
        object = vm.serializeAddress("implementation", "eulerSwapImplementation", implementation);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address poolManager) public broadcast returns (address implementation) {
        implementation = execute(evc, poolManager);
    }

    function execute(address evc, address poolManager) public returns (address implementation) {
        bytes memory bytecode =
            abi.encodePacked(vm.getCode("out-euler-swap/EulerSwap.sol/EulerSwap.json"), abi.encode(evc, poolManager));
        assembly {
            implementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
