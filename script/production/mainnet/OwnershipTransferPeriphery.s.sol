// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, PeripheryAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {SnapshotRegistry} from "../../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernedPerspective} from "../../../src/Perspectives/deployed/GovernedPerspective.sol";

contract OwnershipTransfer is ScriptUtils, PeripheryAddressesLib {
    // Default Perspective management: Euler Labs
    address internal constant EULER_LABS = 0xE130bA997B941f159ADc597F0d89a328554D4B3E;

    address internal constant ORACLE_ADAPTER_REGISTRY_OWNER = EULER_LABS;
    address internal constant EXTERNAL_VAULT_REGISTRY_OWNER = EULER_LABS;
    address internal constant IRM_REGISTRY_OWNER = EULER_LABS;
    address internal constant GOVERNED_PERSPECTIVE_OWNER = EULER_LABS;

    function run() public {
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(getInputConfig("PeripheryAddresses.json"));

        startBroadcast();
        SnapshotRegistry(peripheryAddresses.oracleAdapterRegistry).transferOwnership(ORACLE_ADAPTER_REGISTRY_OWNER);
        SnapshotRegistry(peripheryAddresses.externalVaultRegistry).transferOwnership(EXTERNAL_VAULT_REGISTRY_OWNER);
        SnapshotRegistry(peripheryAddresses.irmRegistry).transferOwnership(IRM_REGISTRY_OWNER);
        GovernedPerspective(peripheryAddresses.governedPerspective).transferOwnership(GOVERNED_PERSPECTIVE_OWNER);
        stopBroadcast();
    }
}
