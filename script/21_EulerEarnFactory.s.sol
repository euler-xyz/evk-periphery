// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerEarnFactory is ScriptUtils {
    function run() public broadcast returns (address eulerEarnfactory) {
        string memory inputScriptFileName = "21_EulerEarnFactory_input.json";
        string memory outputScriptFileName = "21_EulerEarnFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eulerEarnImplementation = vm.parseJsonAddress(json, ".eulerEarnImplementation");

        eulerEarnfactory = execute(eulerEarnImplementation);

        string memory object;
        object = vm.serializeAddress("factory", "eulerEarnfactory", eulerEarnfactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address implementation) public broadcast returns (address factory) {
        factory = execute(implementation);
    }

    function execute(address implementation) public returns (address factory) {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-earn/EulerEarnFactory.sol/EulerEarnFactory.json"), abi.encode(implementation)
        );
        assembly {
            factory := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
