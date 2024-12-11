// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./utils/ScriptUtils.s.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "./../src/ERC20/deployed/RewardToken.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernedPerspective} from "./../src/Perspectives/deployed/GovernedPerspective.sol";

contract OwnershipTransferPeriphery is ScriptUtils {
    function run() public {
        string memory json = getInputConfig("52_OwnershipTransferPeriphery_input.json");
        address eulAdmin = vm.parseJsonAddress(json, ".eulAdmin");
        address rEULOwner = vm.parseJsonAddress(json, ".rEULOwner");
        address oracleAdapterRegistryOwner = vm.parseJsonAddress(json, ".oracleAdapterRegistryOwner");
        address externalVaultRegistryOwner = vm.parseJsonAddress(json, ".externalVaultRegistryOwner");
        address irmRegistryOwner = vm.parseJsonAddress(json, ".irmRegistryOwner");
        address governedPerspectiveOwner = vm.parseJsonAddress(json, ".governedPerspectiveOwner");

        startBroadcast();

        {
            (bool success, bytes memory result) = peripheryAddresses.EUL.staticcall(
                abi.encodeCall(ERC20BurnableMintable(peripheryAddresses.EUL).DEFAULT_ADMIN_ROLE, ())
            );

            if (success && result.length >= 32) {
                bytes32 defaultAdminRole = abi.decode(result, (bytes32));

                if (!ERC20BurnableMintable(peripheryAddresses.EUL).hasRole(defaultAdminRole, eulAdmin)) {
                    console.log("Granting EUL default admin role to the desired address %s", eulAdmin);
                    ERC20BurnableMintable(peripheryAddresses.EUL).grantRole(defaultAdminRole, eulAdmin);
                } else {
                    console.log("EUL default admin role is already set to the desired address. Skipping...");
                }

                if (ERC20BurnableMintable(peripheryAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("Renouncing EUL default admin role from the deployer %s", getDeployer());
                    ERC20BurnableMintable(peripheryAddresses.EUL).renounceRole(defaultAdminRole, getDeployer());
                } else {
                    console.log("The deployer is not the default admin of EUL. Skipping...");
                }
            }
        }

        if (RewardToken(peripheryAddresses.rEUL).owner() != rEULOwner) {
            console.log("Transferring ownership of rEUL to %s", rEULOwner);
            RewardToken(peripheryAddresses.rEUL).transferOwnership(rEULOwner);
        } else {
            console.log("rEUL owner is already set to the desired address. Skipping...");
        }

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
