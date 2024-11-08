// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../../src/Governor/FactoryGovernor.sol";

contract OwnershipTransferCore is ScriptUtils {
    address internal constant EULER_DAO = 0x1e13B0847808045854Ddd908F2d770Dc902Dcfb8;
    address internal constant PROTOCOL_CONFIG_ADMIN = EULER_DAO;
    address internal constant EVAULT_FACTORY_GOVERNOR_ADMIN = EULER_DAO;

    function run() public {
        startBroadcast();
        transferOwnership();
        stopBroadcast();
    }

    function transferOwnership() internal {
        // if called by admin, the script will remove itself from default admin role in factory governor
        require(
            getDeployer() != EVAULT_FACTORY_GOVERNOR_ADMIN, "OwnershipTransferCore: cannot be called by current admin"
        );

        ProtocolConfig(coreAddresses.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), EVAULT_FACTORY_GOVERNOR_ADMIN
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE(), EVAULT_FACTORY_GOVERNOR_ADMIN
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE(), EVAULT_FACTORY_GOVERNOR_ADMIN
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).renounceRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), getDeployer()
        );
        GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(coreAddresses.eVaultFactoryGovernor);
    }
}
