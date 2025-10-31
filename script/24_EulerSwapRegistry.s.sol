// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";

contract EulerSwapRegistryDeployer is ScriptUtils {
    function run() public broadcast returns (address eulerSwapRegistry) {
        string memory inputScriptFileName = "24_EulerSwapRegistry_input.json";
        string memory outputScriptFileName = "24_EulerSwapRegistry_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        address eulerSwapFactory = vm.parseJsonAddress(json, ".eulerSwapFactory");
        address validVaultPerspective = vm.parseJsonAddress(json, ".validVaultPerspective");
        address curator = vm.parseJsonAddress(json, ".curator");

        eulerSwapFactory = execute(evc, eulerSwapFactory, validVaultPerspective, curator);

        string memory object;
        object = vm.serializeAddress("registry", "eulerSwapRegistry", eulerSwapRegistry);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address evc, address eulerSwapFactory, address validVaultPerspective, address curator)
        public
        broadcast
        returns (address eulerSwapRegistry)
    {
        eulerSwapRegistry = execute(evc, eulerSwapFactory, validVaultPerspective, curator);
    }

    function execute(address evc, address eulerSwapFactory, address validVaultPerspective, address curator)
        public
        returns (address eulerSwapRegistry)
    {
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("out-euler-swap/EulerSwapRegistry.sol/EulerSwapRegistry.json"),
            abi.encode(evc, eulerSwapFactory, validVaultPerspective, curator)
        );
        assembly {
            eulerSwapRegistry := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
