// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, console} from "./utils/ScriptUtils.s.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

contract OwnershipTransferCore is BatchBuilder {
    function run() public {
        verifyMultisigAddresses(multisigAddresses);

        if (ProtocolConfig(coreAddresses.protocolConfig).admin() != multisigAddresses.DAO) {
            console.log("Setting ProtocolConfig admin to address %s", multisigAddresses.DAO);
            startBroadcast();
            ProtocolConfig(coreAddresses.protocolConfig).setAdmin(multisigAddresses.DAO);
            stopBroadcast();
        } else {
            console.log("ProtocolConfig admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole = AccessControl(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(
                    defaultAdminRole, multisigAddresses.securityCouncil
                )
            ) {
                console.log(
                    "Granting FactoryGovernor default admin role to address %s", multisigAddresses.securityCouncil
                );
                startBroadcast();
                AccessControl(coreAddresses.eVaultFactoryGovernor).grantRole(
                    defaultAdminRole, multisigAddresses.securityCouncil
                );
                stopBroadcast();
            } else {
                console.log("FactoryGovernor default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(coreAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                console.log("Renouncing FactoryGovernor default admin role from the deployer %s", getDeployer());
                startBroadcast();
                AccessControl(coreAddresses.eVaultFactoryGovernor).renounceRole(defaultAdminRole, getDeployer());
                stopBroadcast();
            } else {
                console.log("The deployer is no longer the default admin of the FactoryGovernor. Skipping...");
            }
        }

        if (GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() != coreAddresses.eVaultFactoryGovernor) {
            console.log(
                "Setting GenericFactory upgrade admin to the eVaultFactoryGovernor address %s",
                coreAddresses.eVaultFactoryGovernor
            );
            startBroadcast();
            GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(coreAddresses.eVaultFactoryGovernor);
            stopBroadcast();
        } else {
            console.log("GenericFactory upgrade admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole = AccessControl(coreAddresses.accessControlEmergencyGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(coreAddresses.accessControlEmergencyGovernor).hasRole(
                    defaultAdminRole, multisigAddresses.DAO
                )
            ) {
                console.log(
                    "Granting GovernorAccessControlEmergency default admin role to address %s", multisigAddresses.DAO
                );
                grantRole(coreAddresses.accessControlEmergencyGovernor, defaultAdminRole, multisigAddresses.DAO);
            } else {
                console.log(
                    "GovernorAccessControlEmergency default admin role is already set to the desired address. Skipping..."
                );
            }

            if (AccessControl(coreAddresses.accessControlEmergencyGovernor).hasRole(defaultAdminRole, getDeployer())) {
                console.log(
                    "Renouncing GovernorAccessControlEmergency default admin role from the deployer %s", getDeployer()
                );
                renounceRole(coreAddresses.accessControlEmergencyGovernor, defaultAdminRole, getDeployer());
            } else {
                console.log(
                    "The deployer is no longer the default admin of the GovernorAccessControlEmergency. Skipping..."
                );
            }
        }

        if (block.chainid != 1) {
            bytes32 defaultAdminRole = AccessControl(coreAddresses.EUL).DEFAULT_ADMIN_ROLE();

            if (!AccessControl(coreAddresses.EUL).hasRole(defaultAdminRole, multisigAddresses.DAO)) {
                console.log("Granting EUL default admin role to address %s", multisigAddresses.DAO);
                grantRole(coreAddresses.EUL, defaultAdminRole, multisigAddresses.DAO);
            } else {
                console.log("EUL default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(coreAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                console.log("Renouncing EUL default admin role from the deployer %s", getDeployer());
                renounceRole(coreAddresses.EUL, defaultAdminRole, getDeployer());
            } else {
                console.log("The deployer is no longer the default admin of EUL. Skipping...");
            }
        }

        if (Ownable(coreAddresses.rEUL).owner() != multisigAddresses.DAO) {
            console.log("Transferring ownership of rEUL to %s", multisigAddresses.DAO);
            transferOwnership(coreAddresses.rEUL, multisigAddresses.DAO);
        } else {
            console.log("rEUL owner is already set to the desired address. Skipping...");
        }

        executeBatch();
    }
}
