// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

contract EVaultFactory is ScriptUtils {
    function run() public broadcast returns (address eVaultFactory) {
        string memory inputScriptFileName = "06_EVaultFactory_input.json";
        string memory outputScriptFileName = "06_EVaultFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultImplementation = vm.parseJsonAddress(json, ".eVaultImplementation");

        eVaultFactory = execute(eVaultImplementation);

        string memory object;
        object = vm.serializeAddress("factory", "eVaultFactory", eVaultFactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eVaultImplementation) public broadcast returns (address eVaultFactory) {
        eVaultFactory = execute(eVaultImplementation);
    }

    function execute(address eVaultImplementation) public returns (address eVaultFactory) {
        eVaultFactory = address(new GenericFactory(getDeployer()));
        GenericFactory(eVaultFactory).setImplementation(eVaultImplementation);
    }
}
