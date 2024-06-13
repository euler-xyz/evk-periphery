// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {EscrowSingletonPerspective} from "../src/Perspectives/deployed/EscrowSingletonPerspective.sol";
import {EulerDefaultClusterPerspective} from "../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";

contract Perspectives is ScriptUtils {
    function run()
        public
        startBroadcast
        returns (address escrowSingletonPerspective, address eulerDefaultClusterPerspective)
    {
        string memory scriptFileName = "09_Peripherals.json";
        string memory json = getInputConfig(scriptFileName);
        address eVaultFactory = abi.decode(vm.parseJson(json, ".eVaultFactory"), (address));
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));

        (escrowSingletonPerspective, eulerDefaultClusterPerspective) =
            deploy(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("perspectives", "escrowSingletonPerspective", escrowSingletonPerspective);
        object = vm.serializeAddress("perspectives", "eulerDefaultClusterPerspective", eulerDefaultClusterPerspective);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory
    ) public returns (address escrowSingletonPerspective, address eulerDefaultClusterPerspective) {
        (escrowSingletonPerspective, eulerDefaultClusterPerspective) =
            execute(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory);
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory
    ) internal returns (address escrowSingletonPerspective, address eulerDefaultClusterPerspective) {
        escrowSingletonPerspective = address(new EscrowSingletonPerspective(eVaultFactory));
        eulerDefaultClusterPerspective = address(
            new EulerDefaultClusterPerspective(
                eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory, escrowSingletonPerspective
            )
        );
    }
}
