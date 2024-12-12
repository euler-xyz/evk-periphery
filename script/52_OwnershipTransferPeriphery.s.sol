// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract OwnershipTransferPeriphery is BatchBuilder {
    function run() public {
        string memory json = getInputConfig("52_OwnershipTransferPeriphery_input.json");
        address oracleAdapterRegistryOwner = vm.parseJsonAddress(json, ".oracleAdapterRegistryOwner");
        address externalVaultRegistryOwner = vm.parseJsonAddress(json, ".externalVaultRegistryOwner");
        address irmRegistryOwner = vm.parseJsonAddress(json, ".irmRegistryOwner");
        address governedPerspectiveOwner = vm.parseJsonAddress(json, ".governedPerspectiveOwner");

        if (Ownable(peripheryAddresses.oracleAdapterRegistry).owner() != oracleAdapterRegistryOwner) {
            console.log("Transferring ownership of OracleAdapterRegistry to %s", oracleAdapterRegistryOwner);
            transferOwnership(peripheryAddresses.oracleAdapterRegistry, oracleAdapterRegistryOwner);
        } else {
            console.log("OracleAdapterRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.externalVaultRegistry).owner() != externalVaultRegistryOwner) {
            console.log("Transferring ownership of ExternalVaultRegistry to %s", externalVaultRegistryOwner);
            transferOwnership(peripheryAddresses.externalVaultRegistry, externalVaultRegistryOwner);
        } else {
            console.log("ExternalVaultRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.irmRegistry).owner() != irmRegistryOwner) {
            console.log("Transferring ownership of IRMRegistry to %s", irmRegistryOwner);
            transferOwnership(peripheryAddresses.irmRegistry, irmRegistryOwner);
        } else {
            console.log("IRMRegistry owner is already set to the desired address. Skipping...");
        }

        if (Ownable(peripheryAddresses.governedPerspective).owner() != governedPerspectiveOwner) {
            console.log("Transferring ownership of GovernedPerspective to %s", governedPerspectiveOwner);
            transferOwnership(peripheryAddresses.governedPerspective, governedPerspectiveOwner);
        } else {
            console.log("GovernedPerspective owner is already set to the desired address. Skipping...");
        }

        executeBatch();
    }
}
