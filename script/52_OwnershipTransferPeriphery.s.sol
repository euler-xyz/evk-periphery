// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./utils/ScriptUtils.s.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernedPerspective} from "./../src/Perspectives/deployed/GovernedPerspective.sol";

contract OwnershipTransferPeriphery is ScriptUtils {
    function run() public {
        string memory json = getInputConfig("52_OwnershipTransferPeriphery_input.json");
        address oracleAdapterRegistryOwner = vm.parseJsonAddress(json, ".oracleAdapterRegistryOwner");
        address externalVaultRegistryOwner = vm.parseJsonAddress(json, ".externalVaultRegistryOwner");
        address irmRegistryOwner = vm.parseJsonAddress(json, ".irmRegistryOwner");
        address governedPerspectiveOwner = vm.parseJsonAddress(json, ".governedPerspectiveOwner");

        startBroadcast();

        if (SnapshotRegistry(peripheryAddresses.oracleAdapterRegistry).owner() != oracleAdapterRegistryOwner) {
            console.log("Transferring ownership of OracleAdapterRegistry to %s", oracleAdapterRegistryOwner);
            SnapshotRegistry(peripheryAddresses.oracleAdapterRegistry).transferOwnership(oracleAdapterRegistryOwner);
        } else {
            console.log("OracleAdapterRegistry owner is already set to the desired address. Skipping...");
        }

        if (SnapshotRegistry(peripheryAddresses.externalVaultRegistry).owner() != externalVaultRegistryOwner) {
            console.log("Transferring ownership of ExternalVaultRegistry to %s", externalVaultRegistryOwner);
            SnapshotRegistry(peripheryAddresses.externalVaultRegistry).transferOwnership(externalVaultRegistryOwner);
        } else {
            console.log("ExternalVaultRegistry owner is already set to the desired address. Skipping...");
        }

        if (SnapshotRegistry(peripheryAddresses.irmRegistry).owner() != irmRegistryOwner) {
            console.log("Transferring ownership of IRMRegistry to %s", irmRegistryOwner);
            SnapshotRegistry(peripheryAddresses.irmRegistry).transferOwnership(irmRegistryOwner);
        } else {
            console.log("IRMRegistry owner is already set to the desired address. Skipping...");
        }

        if (GovernedPerspective(peripheryAddresses.governedPerspective).owner() != governedPerspectiveOwner) {
            console.log("Transferring ownership of GovernedPerspective to %s", governedPerspectiveOwner);
            GovernedPerspective(peripheryAddresses.governedPerspective).transferOwnership(governedPerspectiveOwner);
        } else {
            console.log("GovernedPerspective owner is already set to the desired address. Skipping...");
        }

        stopBroadcast();
    }
}
