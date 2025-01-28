// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EdgeFactory} from "../src/EdgeFactory/EdgeFactory.sol";

contract EdgeFactoryDeployer is ScriptUtils {
    function run() public broadcast returns (address edgeFactory) {
        string memory inputScriptFileName = "15_EdgeFactory_input.json";
        string memory outputScriptFileName = "15_EdgeFactory_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address eVaultFactory = vm.parseJsonAddress(json, ".eVaultFactory");
        address oracleRouterFactory = vm.parseJsonAddress(json, ".oracleRouterFactory");
        address escrowedCollateralPerspective = vm.parseJsonAddress(json, ".escrowedCollateralPerspective");

        edgeFactory = execute(eVaultFactory, oracleRouterFactory, escrowedCollateralPerspective);

        string memory object;
        object = vm.serializeAddress("factory", "edgeFactory", edgeFactory);

        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address eVaultFactory, address oracleRouterFactory, address escrowedCollateralPerspective)
        public
        broadcast
        returns (address edgeFactory)
    {
        edgeFactory = execute(eVaultFactory, oracleRouterFactory, escrowedCollateralPerspective);
    }

    function execute(address eVaultFactory, address oracleRouterFactory, address escrowedCollateralPerspective)
        public
        returns (address edgeFactory)
    {
        edgeFactory = address(new EdgeFactory(eVaultFactory, oracleRouterFactory, escrowedCollateralPerspective));
    }
}
