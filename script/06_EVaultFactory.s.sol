// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

contract EVaultFactory is ScriptUtils {
    function run() public startBroadcast returns (address eVaultFactory) {
        string memory scriptFileName = "06_EVaultFactory.json";
        string memory json = getInputConfig(scriptFileName);
        address eVaultImplementation = abi.decode(vm.parseJson(json, ".eVaultImplementation"), (address));

        eVaultFactory = execute(eVaultImplementation);

        string memory object;
        object = vm.serializeAddress("factory", "eVaultFactory", eVaultFactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(address eVaultImplementation) public returns (address eVaultFactory) {
        eVaultFactory = execute(eVaultImplementation);
    }

    function execute(address eVaultImplementation) internal returns (address eVaultFactory) {
        eVaultFactory = address(new GenericFactory(getDeployer()));
        GenericFactory(eVaultFactory).setImplementation(eVaultImplementation);
    }
}
