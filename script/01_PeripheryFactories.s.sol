// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {EulerRouterFactory} from "../src/OracleFactory/EulerRouterFactory.sol";
import {AdapterRegistry} from "../src/OracleFactory/AdapterRegistry.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";

contract PeripheryFactories is ScriptUtils {
    function run()
        public
        startBroadcast
        returns (address oracleRouterFactory, address oracleAdapterRegistry, address kinkIRMFactory)
    {
        string memory scriptFileName = "01_PeripheryFactories.json";

        (oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory) = execute();

        string memory object;
        object = vm.serializeAddress("peripheryFactories", "oracleRouterFactory", oracleRouterFactory);
        object = vm.serializeAddress("peripheryFactories", "oracleAdapterRegistry", oracleAdapterRegistry);
        object = vm.serializeAddress("peripheryFactories", "kinkIRMFactory", kinkIRMFactory);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy()
        public
        startBroadcast
        returns (address oracleRouterFactory, address oracleAdapterRegistry, address kinkIRMFactory)
    {
        (oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory) = execute();
    }

    function execute()
        public
        returns (address oracleRouterFactory, address oracleAdapterRegistry, address kinkIRMFactory)
    {
        oracleRouterFactory = address(new EulerRouterFactory());
        oracleAdapterRegistry = address(new AdapterRegistry(getDeployer()));
        kinkIRMFactory = address(new EulerKinkIRMFactory());
    }
}
