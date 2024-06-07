// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./ScriptUtils.s.sol";
import {AccountLens} from "../src/Lens/AccountLens.sol";
import {OracleLens} from "../src/Lens/OracleLens.sol";
import {VaultLens} from "../src/Lens/VaultLens.sol";
import {EscrowSingletonPerspective} from
    "../src/Perspectives/immutable/ungoverned/escrow/EscrowSingletonPerspective.sol";
import {ClusterConservativePerspective} from
    "../src/Perspectives/immutable/ungoverned/cluster/ClusterConservativePerspective.sol";

contract Peripherals is ScriptUtils {
    function run()
        public
        startBroadcast
        returns (
            address accountLens,
            address oracleLens,
            address vaultLens,
            address escrowSingletonPerspective,
            address clusterConservativePerspective
        )
    {
        string memory scriptFileName = "08_Peripherals.json";
        string memory json = getInputConfig(scriptFileName);
        address eVaultFactory = abi.decode(vm.parseJson(json, ".eVaultFactory"), (address));
        address oracleRouterFactory = abi.decode(vm.parseJson(json, ".oracleRouterFactory"), (address));
        address oracleAdapterRegistry = abi.decode(vm.parseJson(json, ".oracleAdapterRegistry"), (address));
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));

        (accountLens, oracleLens, vaultLens, escrowSingletonPerspective, clusterConservativePerspective) =
            deploy(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory);

        string memory object;
        object = vm.serializeAddress("peripherals", "accountLens", accountLens);
        object = vm.serializeAddress("peripherals", "oracleLens", oracleLens);
        object = vm.serializeAddress("peripherals", "vaultLens", vaultLens);
        object = vm.serializeAddress("peripherals", "escrowSingletonPerspective", escrowSingletonPerspective);
        object = vm.serializeAddress("peripherals", "clusterConservativePerspective", clusterConservativePerspective);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory
    )
        public
        returns (
            address accountLens,
            address oracleLens,
            address vaultLens,
            address escrowSingletonPerspective,
            address clusterConservativePerspective
        )
    {
        (accountLens, oracleLens, vaultLens, escrowSingletonPerspective, clusterConservativePerspective) =
            execute(eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory);
    }

    function execute(
        address eVaultFactory,
        address oracleRouterFactory,
        address oracleAdapterRegistry,
        address kinkIRMFactory
    )
        internal
        returns (
            address accountLens,
            address oracleLens,
            address vaultLens,
            address escrowSingletonPerspective,
            address clusterConservativePerspective
        )
    {
        accountLens = address(new AccountLens());
        oracleLens = address(new OracleLens());
        vaultLens = address(new VaultLens(address(oracleLens)));
        escrowSingletonPerspective = address(new EscrowSingletonPerspective(eVaultFactory));
        clusterConservativePerspective = address(
            new ClusterConservativePerspective(
                eVaultFactory, oracleRouterFactory, oracleAdapterRegistry, kinkIRMFactory, escrowSingletonPerspective
            )
        );
    }
}
