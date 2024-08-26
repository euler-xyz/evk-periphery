// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreInfoLib} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {SnapshotRegistry} from "../../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernableWhitelistPerspective} from "../../../src/Perspectives/deployed/GovernableWhitelistPerspective.sol";

contract OwnershipTransfer is ScriptUtils, CoreInfoLib {
    // Revenue and Upgrade functionality: Euler DAO
    address internal constant EULER_DAO = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant PROTOCOL_CONFIG_ADMIN = EULER_DAO;
    address internal constant EVAULT_FACTORY_UPGRADE_ADMIN = EULER_DAO;

    // Default Perspective management: Euler Labs
    address internal constant EULER_LABS = 0xE130bA997B941f159ADc597F0d89a328554D4B3E;

    address internal constant ORACLE_ADAPTER_REGISTRY_OWNER = EULER_LABS;
    address internal constant EXTERNAL_VAULT_REGISTRY_OWNER = EULER_LABS;
    address internal constant IRM_REGISTRY_OWNER = EULER_LABS;
    address internal constant GOVERNABLE_WHITELIST_PERSPECTIVE_OWNER = EULER_LABS;

    function run() public {
        CoreInfo memory coreInfo =
            deserializeCoreInfo(vm.readFile(string.concat(vm.projectRoot(), "/script/CoreInfo.json")));

        startBroadcast();
        ProtocolConfig(coreInfo.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        GenericFactory(coreInfo.eVaultFactory).setUpgradeAdmin(EVAULT_FACTORY_UPGRADE_ADMIN);
        SnapshotRegistry(coreInfo.oracleAdapterRegistry).transferOwnership(ORACLE_ADAPTER_REGISTRY_OWNER);
        SnapshotRegistry(coreInfo.externalVaultRegistry).transferOwnership(EXTERNAL_VAULT_REGISTRY_OWNER);
        SnapshotRegistry(coreInfo.irmRegistry).transferOwnership(IRM_REGISTRY_OWNER);
        GovernableWhitelistPerspective(coreInfo.governableWhitelistPerspective).transferOwnership(
            GOVERNABLE_WHITELIST_PERSPECTIVE_OWNER
        );
        stopBroadcast();
    }
}
