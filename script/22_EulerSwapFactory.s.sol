// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapFactoryDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerSwapFactory) {
        string memory inputScriptFileName = "22_EulerSwapFactory_input.json";
        string memory outputScriptFileName = "22_EulerSwapFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address eulerSwapImplementation = vm.parseJsonAddress(json, ".eulerSwapImplementation");

        eulerSwapFactory = execute(evc, eulerSwapImplementation);

        string memory object;
        object = vm.serializeAddress("factory", "eulerSwapFactory", eulerSwapFactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address eulerSwapImplementation) public broadcast returns (address eulerSwapFactory) {
        eulerSwapFactory = execute(evc, eulerSwapImplementation);
    }

    function execute(address evc, address eulerSwapImplementation) public returns (address eulerSwapFactory) {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwapFactory.sol/EulerSwapFactory.json"),
            abi.encode(evc, eulerSwapImplementation)
        );
        assembly {
            eulerSwapFactory := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
