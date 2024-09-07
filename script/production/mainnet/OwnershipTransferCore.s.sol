// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {FactoryGovernor} from "../../../src/Governor/FactoryGovernor.sol";

contract OwnershipTransferCore is ScriptUtils {
    // Revenue and Upgrade functionality: Euler DAO
    address internal constant EULER_DAO = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant PROTOCOL_CONFIG_ADMIN = EULER_DAO;
    address internal constant EVAULT_FACTORY_GOVERNOR_ADMIN = EULER_DAO;

    function run() public {
        startBroadcast();
        ProtocolConfig(coreAddresses.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), EVAULT_FACTORY_GOVERNOR_ADMIN
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).grantRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).GUARDIAN_ROLE(), EVAULT_FACTORY_GOVERNOR_ADMIN
        );
        FactoryGovernor(coreAddresses.eVaultFactoryGovernor).renounceRole(
            FactoryGovernor(coreAddresses.eVaultFactoryGovernor).DEFAULT_ADMIN_ROLE(), getDeployer()
        );
        GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(coreAddresses.eVaultFactoryGovernor);
        stopBroadcast();
    }
}
