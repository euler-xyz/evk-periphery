// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapFactory is ScriptUtils {
    function run() public broadcast returns (address eulerSwapFactory) {
        string memory inputScriptFileName = "23_EulerSwapFactory_input.json";
        string memory outputScriptFileName = "23_EulerSwapFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address eulerSwapImplementation = vm.parseJsonAddress(json, ".eulerSwapImplementation");
        address feeOwner = vm.parseJsonAddress(json, ".feeOwner");
        address feeRecipientSetter = vm.parseJsonAddress(json, ".feeRecipientSetter");

        eulerSwapFactory = execute(evc, eVaultFactory, eulerSwapImplementation, feeOwner, feeRecipientSetter);

        string memory object;
        object = vm.serializeAddress("factory", "eulerSwapFactory", eulerSwapFactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address evc,
        address eVaultFactory,
        address eulerSwapImplementation,
        address feeOwner,
        address feeRecipientSetter
    ) public broadcast returns (address eulerSwapFactory) {
        eulerSwapFactory = execute(evc, eVaultFactory, eulerSwapImplementation, feeOwner, feeRecipientSetter);
    }

    function execute(
        address evc,
        address eVaultFactory,
        address eulerSwapImplementation,
        address feeOwner,
        address feeRecipientSetter
    ) public returns (address eulerSwapFactory) {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwapFactory.sol/EulerSwapFactory.json"),
            abi.encode(evc, eVaultFactory, eulerSwapImplementation, feeOwner, feeRecipientSetter)
        );
        assembly {
            eulerSwapFactory := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
