// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
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
        // if called by admin, the script will remove itself from default admin role in factory governor
        require(getDeployer() != eVaultFactoryGovernorAdmin, "OwnershipTransferCore: cannot be called by current admin");

        ProtocolConfig(coreAddresses.protocolConfig).setAdmin(protocolConfigAdmin);
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), eVaultFactoryGovernorAdmin
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE(), eVaultFactoryGovernorAdmin
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE(), eVaultFactoryGovernorAdmin
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).renounceRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), getDeployer()
        );
        GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(coreAddresses.eVaultFactoryGovernor);
    }
}
