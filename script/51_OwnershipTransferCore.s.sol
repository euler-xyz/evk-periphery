// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, console} from "./utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";

contract OwnershipTransferCore is ScriptUtils {
    function run() public {
        string memory json = getInputConfig("51_OwnershipTransferCore_input.json");
        address protocolConfigAdmin = vm.parseJsonAddress(json, ".protocolConfigAdmin");
        address eVaultFactoryGovernorAdmin = vm.parseJsonAddress(json, ".eVaultFactoryGovernorAdmin");

        startBroadcast();
        transferOwnership(protocolConfigAdmin, eVaultFactoryGovernorAdmin);
        stopBroadcast();
    }

    function transferOwnership(address protocolConfigAdmin, address eVaultFactoryGovernorAdmin) internal {
        // if called by admin, the script will remove itself from default admin role in the factory governor
        require(getDeployer() != eVaultFactoryGovernorAdmin, "OwnershipTransferCore: cannot be called by current admin");

        if (ProtocolConfig(coreAddresses.protocolConfig).admin() != protocolConfigAdmin) {
            console.log("Setting ProtocolConfig admin to the desired address %s", protocolConfigAdmin);
            ProtocolConfig(coreAddresses.protocolConfig).setAdmin(protocolConfigAdmin);
        } else {
            console.log("ProtocolConfig admin is already set to the desired address. Skipping...");
        }

        bytes32 defaultAdminRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE();
        bytes32 pauseGuardianRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE();
        bytes32 unpauseAdminRole = FactoryGovernor(coreAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE();

        if (!FactoryGovernor(coreAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, eVaultFactoryGovernorAdmin))
        {
            console.log(
                "Granting FactoryGovernor default admin role to the desired address %s", eVaultFactoryGovernorAdmin
            );
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(defaultAdminRole, eVaultFactoryGovernorAdmin);
        } else {
            console.log("FactoryGovernor default admin role is already set to the desired address. Skipping...");
        }

        if (
            !FactoryGovernor(coreAddresses.eVaultFactoryGovernor).hasRole(pauseGuardianRole, eVaultFactoryGovernorAdmin)
        ) {
            console.log(
                "Granting FactoryGovernor pause guardian role to the desired address %s", eVaultFactoryGovernorAdmin
            );
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
                pauseGuardianRole, eVaultFactoryGovernorAdmin
            );
        } else {
            console.log("FactoryGovernor pause guardian role is already set to the desired address. Skipping...");
        }

        if (!FactoryGovernor(coreAddresses.eVaultFactoryGovernor).hasRole(unpauseAdminRole, eVaultFactoryGovernorAdmin))
        {
            console.log(
                "Granting FactoryGovernor unpause admin role to the desired address %s", eVaultFactoryGovernorAdmin
            );
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(unpauseAdminRole, eVaultFactoryGovernorAdmin);
        } else {
            console.log("FactoryGovernor unpause admin role is already set to the desired address. Skipping...");
        }

        if (FactoryGovernor(coreAddresses.eVaultFactoryGovernor).hasRole(defaultAdminRole, getDeployer())) {
            console.log("Renouncing FactoryGovernor default admin role from the deployer %s", getDeployer());
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).renounceRole(defaultAdminRole, getDeployer());
        } else {
            console.log("The deployer is not the default admin of the factory governor. Skipping...");
        }

        if (GenericFactory(coreAddresses.eVaultFactory).upgradeAdmin() != coreAddresses.eVaultFactoryGovernor) {
            console.log(
                "Setting GenericFactory upgrade admin to the eVaultFactoryGovernor address %s",
                coreAddresses.eVaultFactoryGovernor
            );
            GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(coreAddresses.eVaultFactoryGovernor);
        } else {
            console.log("GenericFactory upgrade admin is already set to the desired address. Skipping...");
        }
    }
}
