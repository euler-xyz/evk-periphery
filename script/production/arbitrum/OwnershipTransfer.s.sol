// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreInfoLib} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {SnapshotRegistry} from "../../../src/OracleFactory/SnapshotRegistry.sol";
import {GovernableWhitelistPerspective} from "../../../src/Perspectives/deployed/GovernableWhitelistPerspective.sol";

contract OwnershipTransfer is ScriptUtils, CoreInfoLib {
    address internal constant PROTOCOL_CONFIG_ADMIN = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant EVAULT_FACTORY_UPGRADE_ADMIN = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant ORACLE_ADAPTER_REGISTRY_OWNER = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant EXTERNAL_VAULT_REGISTRY_OWNER = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant GOVERNABLE_WHITELIST_PERSPECTIVE_OWNER = 0x0000000000000000000000000000000000000000; // TODO

    function run() public {
        CoreInfo memory coreInfo =
            deserializeCoreInfo(vm.readFile(string.concat(vm.projectRoot(), "/script/CoreInfo.json")));

        startBroadcast();
        ProtocolConfig(coreInfo.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        GenericFactory(coreInfo.eVaultFactory).setUpgradeAdmin(EVAULT_FACTORY_UPGRADE_ADMIN);
        SnapshotRegistry(coreInfo.oracleAdapterRegistry).transferOwnership(ORACLE_ADAPTER_REGISTRY_OWNER);
        SnapshotRegistry(coreInfo.externalVaultRegistry).transferOwnership(EXTERNAL_VAULT_REGISTRY_OWNER);
        GovernableWhitelistPerspective(coreInfo.governableWhitelistPerspective).transferOwnership(
            GOVERNABLE_WHITELIST_PERSPECTIVE_OWNER
        );
        stopBroadcast();
    }
}
