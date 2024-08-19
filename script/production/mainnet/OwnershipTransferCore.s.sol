// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

contract OwnershipTransferCore is ScriptUtils, CoreAddressesLib {
    // Revenue and Upgrade functionality: Euler DAO
    address internal constant EULER_DAO = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant PROTOCOL_CONFIG_ADMIN = EULER_DAO;
    address internal constant EVAULT_FACTORY_UPGRADE_ADMIN = EULER_DAO;

    function run() public {
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(getInputConfig("CoreAddresses.json"));

        startBroadcast();
        ProtocolConfig(coreAddresses.protocolConfig).setAdmin(PROTOCOL_CONFIG_ADMIN);
        GenericFactory(coreAddresses.eVaultFactory).setUpgradeAdmin(EVAULT_FACTORY_UPGRADE_ADMIN);
        stopBroadcast();
    }
}
