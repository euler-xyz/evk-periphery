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

        address privilegedAddress = ProtocolConfig(coreAddresses.protocolConfig).admin();
        if (privilegedAddress != multisigAddresses.DAO) {
            if (privilegedAddress != getDeployer()) {
                console.log("+ Setting ProtocolConfig admin to address %s", multisigAddresses.DAO);
                startBroadcast();
                ProtocolConfig(coreAddresses.protocolConfig).setAdmin(multisigAddresses.DAO);
                stopBroadcast();
            } else {
                console.log("! ProtocolConfig admin is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- ProtocolConfig admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole = AccessControl(governorAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, multisigAddresses.DAO)
            ) {
                if (AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("+ Granting FactoryGovernor default admin role to address %s", multisigAddresses.DAO);
                    startBroadcast();
                    AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(
                        defaultAdminRole, multisigAddresses.DAO
                    );
                    stopBroadcast();
                } else {
                    console.log("! FactoryGovernor default admin role is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- FactoryGovernor default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(governorAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
                console.log("+ Renouncing FactoryGovernor default admin role from the deployer %s", getDeployer());
                startBroadcast();
                AccessControl(governorAddresses.eVaultFactoryGovernor).renounceRole(defaultAdminRole, getDeployer());
                stopBroadcast();
            } else {
                console.log("- The deployer is no longer the default admin of the FactoryGovernor. Skipping...");
            }
        }

        privilegedAddress = GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin();
        if (privilegedAddress != governorAddresses.eVaultFactoryGovernor) {
            if (privilegedAddress != getDeployer()) {
                console.log(
                    "+ Setting EVaultFactory upgrade admin to the EVaultFactoryGovernor address %s",
                    governorAddresses.eVaultFactoryGovernor
                );
                startBroadcast();
                GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(governorAddresses.eVaultFactoryGovernor);
                stopBroadcast();
            } else {
                console.log("! EVaultFactory upgrade admin is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- EVaultFactory upgrade admin is already set to the desired address. Skipping...");
        }

        {
            bytes32 defaultAdminRole =
                AccessControl(governorAddresses.accessControlEmergencyGovernor).DEFAULT_ADMIN_ROLE();

            if (
                !AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(
                    defaultAdminRole, multisigAddresses.DAO
                )
            ) {
                if (
                    AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(
                        defaultAdminRole, getDeployer()
                    )
                ) {
                    console.log(
                        "+ Granting GovernorAccessControlEmergency default admin role to address %s",
                        multisigAddresses.DAO
                    );
                    grantRole(governorAddresses.accessControlEmergencyGovernor, defaultAdminRole, multisigAddresses.DAO);
                } else {
                    console.log(
                        "! GovernorAccessControlEmergency default admin role is not the caller of this script. Skipping..."
                    );
                }
            } else {
                console.log(
                    "- GovernorAccessControlEmergency default admin role is already set to the desired address. Skipping..."
                );
            }

            if (
                AccessControl(governorAddresses.accessControlEmergencyGovernor).hasRole(defaultAdminRole, getDeployer())
            ) {
                console.log(
                    "+ Renouncing GovernorAccessControlEmergency default admin role from the deployer %s", getDeployer()
                );
                renounceRole(governorAddresses.accessControlEmergencyGovernor, defaultAdminRole, getDeployer());
            } else {
                console.log(
                    "- The deployer is no longer the default admin of the GovernorAccessControlEmergency. Skipping..."
                );
            }
        }

        if (block.chainid != 1) {
            bytes32 defaultAdminRole = AccessControl(tokenAddresses.EUL).DEFAULT_ADMIN_ROLE();

            startBroadcast();
            if (!AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, multisigAddresses.DAO)) {
                if (AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                    console.log("+ Granting EUL default admin role to address %s", multisigAddresses.DAO);
                    AccessControl(tokenAddresses.EUL).grantRole(defaultAdminRole, multisigAddresses.DAO);
                } else {
                    console.log("! EUL default admin role is not the caller of this script. Skipping...");
                }
            } else {
                console.log("- EUL default admin role is already set to the desired address. Skipping...");
            }

            if (AccessControl(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                console.log("+ Renouncing EUL default admin role from the deployer %s", getDeployer());
                AccessControl(tokenAddresses.EUL).renounceRole(defaultAdminRole, getDeployer());
            } else {
                console.log("- The deployer is no longer the default admin of EUL. Skipping...");
            }
            stopBroadcast();
        }

        privilegedAddress = Ownable(tokenAddresses.rEUL).owner();
        if (privilegedAddress != multisigAddresses.DAO) {
            if (privilegedAddress != getDeployer()) {
                console.log("+ Transferring ownership of rEUL to %s", multisigAddresses.DAO);
                transferOwnership(tokenAddresses.rEUL, multisigAddresses.DAO);
            } else {
                console.log("! rEUL owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log("- rEUL owner is already set to the desired address. Skipping...");
        }

        privilegedAddress = Ownable(nttAddresses.manager).owner();
        if (
            privilegedAddress != multisigAddresses.DAO
                || Ownable(nttAddresses.transceiver).owner() != multisigAddresses.DAO
        ) {
            if (privilegedAddress != getDeployer()) {
                console.log(
                    "+ Transferring ownership of NttManager and WormholeTransceiver to %s", multisigAddresses.DAO
                );
                startBroadcast();
                Ownable(nttAddresses.manager).transferOwnership(multisigAddresses.DAO);
                stopBroadcast();
            } else {
                console.log("! NttManager owner is not the caller of this script. Skipping...");
            }
        } else {
            console.log(
                "- NttManager owner and WormholeTransceiver owner are already set to the desired address. Skipping..."
            );
        }

        executeBatch();
    }
}
