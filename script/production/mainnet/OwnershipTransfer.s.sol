// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {SnapshotRegistry} from "../../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernedPerspective} from "../../../src/Perspectives/deployed/GovernedPerspective.sol";

contract OwnershipTransfer is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib {
    // Revenue and Upgrade functionality: Euler DAO
    address internal constant EULER_DAO = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant PROTOCOL_CONFIG_ADMIN = EULER_DAO;
    address internal constant EVAULT_FACTORY_UPGRADE_ADMIN = EULER_DAO;

    // Default Perspective management: Euler Labs
    address internal constant EULER_LABS = 0xE130bA997B941f159ADc597F0d89a328554D4B3E;

    address internal constant ORACLE_ADAPTER_REGISTRY_OWNER = EULER_LABS;
    address internal constant EXTERNAL_VAULT_REGISTRY_OWNER = EULER_LABS;
    address internal constant IRM_REGISTRY_OWNER = EULER_LABS;
    address internal constant GOVERNED_PERSPECTIVE_OWNER = EULER_LABS;

    function run() public {
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(getInputConfig("CoreAddresses.json"));
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(getInputConfig("PeripheryAddresses.json"));
        ExtraAddresses memory extraAddresses = deserializeExtraAddresses(getInputConfig("ExtraAddresses.json"));

        startBroadcast();
        ProtocolConfig(coreAddresses.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(EVAULT_FACTORY_UPGRADE_ADMIN);
        SnapshotRegistry(peripheryAddresses.oracleAdapterRegistry).transferOwnership(ORACLE_ADAPTER_REGISTRY_OWNER);
        SnapshotRegistry(peripheryAddresses.externalVaultRegistry).transferOwnership(EXTERNAL_VAULT_REGISTRY_OWNER);
        SnapshotRegistry(peripheryAddresses.irmRegistry).transferOwnership(IRM_REGISTRY_OWNER);
        GovernedPerspective(extraAddresses.governedPerspective).transferOwnership(GOVERNED_PERSPECTIVE_OWNER);
        stopBroadcast();
    }
}
