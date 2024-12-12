// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";

contract OwnershipTransferCore is BatchBuilder {
    function run() public {
        string memory json = getInputConfig("51_OwnershipTransferCore_input.json");
        address protocolConfigAdmin = vm.parseJsonAddress(json, ".protocolConfigAdmin");
        address eVaultFactoryGovernorAdmin = vm.parseJsonAddress(json, ".eVaultFactoryGovernorAdmin");
        address eulerAccessControlEmergencyGovernorAdmin =
            vm.parseJsonAddress(json, ".eulerAccessControlEmergencyGovernorAdmin");
        address eulAdmin = vm.parseJsonAddress(json, ".eulAdmin");
        address rEULOwner = vm.parseJsonAddress(json, ".rEULOwner");

        // if called by admin, the script will remove itself from default admin role in the factory governor
        require(getDeployer() != eVaultFactoryGovernorAdmin, "OwnershipTransferCore: cannot be called by current admin");

        if (ProtocolConfig(coreAddresses.protocolConfig).admin() != protocolConfigAdmin) {
            console.log("Setting ProtocolConfig admin to the desired address %s", protocolConfigAdmin);
            setAdmin(coreAddresses.protocolConfig, protocolConfigAdmin);
        } else {
            console.log("ProtocolConfig admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole = AccessControl(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE();
            bytes32 pauseGuardianRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE();
            bytes32 unpauseAdminRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE();

            if (
                !AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, eVaultFactoryGovernorAdmin)
            ) {
                console.log(
                    "Granting FactoryGovernor default admin role to the desired address %s", eVaultFactoryGovernorAdmin
                );
                grantRole(coreAddresses.eVaultFactoryGovernor, defaultAdminRole, eVaultFactoryGovernorAdmin);
            } else {
                console.log("FactoryGovernor default admin role is already set to the desired address. Skipping...");
            }

            if (
                !AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(
                    pauseGuardianRole, eVaultFactoryGovernorAdmin
                )
            ) {
                console.log(
                    "Granting FactoryGovernor pause guardian role to the desired address %s", eVaultFactoryGovernorAdmin
                );
                grantRole(coreAddresses.eVaultFactoryGovernor, pauseGuardianRole, eVaultFactoryGovernorAdmin);
            } else {
                console.log("FactoryGovernor pause guardian role is already set to the desired address. Skipping...");
            }

            if (
                !AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(unpauseAdminRole, eVaultFactoryGovernorAdmin)
            ) {
                console.log(
                    "Granting FactoryGovernor unpause admin role to the desired address %s", eVaultFactoryGovernorAdmin
                );
                grantRole(coreAddresses.eVaultFactoryGovernor, unpauseAdminRole, eVaultFactoryGovernorAdmin);
            } else {
                console.log("FactoryGovernor unpause admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                console.log("Renouncing FactoryGovernor default admin role from the deployer %s", getDeployer());
                renounceRole(coreAddresses.eVaultFactoryGovernor, defaultAdminRole, getDeployer());
            } else {
                console.log("The deployer is not the default admin of the FactoryGovernor. Skipping...");
            }
        }

        if (GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() != coreAddresses.eVaultFactoryGovernor) {
            console.log(
                "Setting GenericFactory upgrade admin to the eVaultFactoryGovernor address %s",
                coreAddresses.eVaultFactoryGovernor
            );
            setUpgradeAdmin(coreAddresses.eVaultFactory, coreAddresses.eVaultFactoryGovernor);
        } else {
            console.log("GenericFactory upgrade admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole =
                AccessControl(coreAddresses.eulerAccessControlEmergencyGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(coreAddresses.eulerAccessControlEmergencyGovernor).hasRole(
                    defaultAdminRole, eulerAccessControlEmergencyGovernorAdmin
                )
            ) {
                console.log(
                    "Granting GovernorAccessControlEmergency default admin role to the desired address %s",
                    eulerAccessControlEmergencyGovernorAdmin
                );
                grantRole(
                    coreAddresses.eulerAccessControlEmergencyGovernor,
                    defaultAdminRole,
                    eulerAccessControlEmergencyGovernorAdmin
                );
            } else {
                console.log(
                    "GovernorAccessControlEmergency default admin role is already set to the desired address. Skipping..."
                );
            }

            if (
                AccessControl(coreAddresses.eulerAccessControlEmergencyGovernor).hasRole(
                    defaultAdminRole, getDeployer()
                )
            ) {
                console.log(
                    "Renouncing GovernorAccessControlEmergency default admin role from the deployer %s", getDeployer()
                );
                renounceRole(coreAddresses.eulerAccessControlEmergencyGovernor, defaultAdminRole, getDeployer());
            } else {
                console.log("The deployer is not the default admin of the GovernorAccessControlEmergency. Skipping...");
            }
        }

        {
            (bool success, bytes memory result) =
                coreAddresses.EUL.staticcall(abi.encodeCall(AccessControl(coreAddresses.EUL).DEFAULT_ADMIN_ROLE, ()));

            if (success && result.length >= 32) {
                bytes32 defaultAdminRole = abi.decode(result, (bytes32));

                if (!AccessControl(coreAddresses.EUL).hasRole(defaultAdminRole, eulAdmin)) {
                    console.log("Granting EUL default admin role to the desired address %s", eulAdmin);
                    grantRole(coreAddresses.EUL, defaultAdminRole, eulAdmin);
                } else {
                    console.log("EUL default admin role is already set to the desired address. Skipping...");
                }

                if (AccessControl(coreAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("Renouncing EUL default admin role from the deployer %s", getDeployer());
                    renounceRole(coreAddresses.EUL, defaultAdminRole, getDeployer());
                } else {
                    console.log("The deployer is not the default admin of EUL. Skipping...");
                }
            }
        }

        if (Ownable(coreAddresses.rEUL).owner() != rEULOwner) {
            console.log("Transferring ownership of rEUL to %s", rEULOwner);
            transferOwnership(coreAddresses.rEUL, rEULOwner);
        } else {
            console.log("rEUL owner is already set to the desired address. Skipping...");
        }

        executeBatch();
    }
}
