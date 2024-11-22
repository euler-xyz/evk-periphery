// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {SnapshotRegistry} from "./../src/SnapshotRegistry/SnapshotRegistry.sol";
import {GovernedPerspective} from "./../src/Perspectives/deployed/GovernedPerspective.sol";

contract OwnershipTransferPeriphery is ScriptUtils {
    function run() public {
        string memory json = getInputConfig("52_OwnershipTransferPeriphery_input.json");
        address oracleAdapterRegistryOwner = vm.parseJsonAddress(json, ".oracleAdapterRegistryOwner");
        address externalVaultRegistryOwner = vm.parseJsonAddress(json, ".externalVaultRegistryOwner");
        address irmRegistryOwner = vm.parseJsonAddress(json, ".irmRegistryOwner");
        address governedPerspectiveOwner = vm.parseJsonAddress(json, ".governedPerspectiveOwner");

        startBroadcast();
        SnapshotRegistry(peripheryAddresses.oracleAdapterRegistry).transferOwnership(oracleAdapterRegistryOwner);
        SnapshotRegistry(peripheryAddresses.externalVaultRegistry).transferOwnership(externalVaultRegistryOwner);
        SnapshotRegistry(peripheryAddresses.irmRegistry).transferOwnership(irmRegistryOwner);
        GovernedPerspective(peripheryAddresses.governedPerspective).transferOwnership(governedPerspectiveOwner);
        stopBroadcast();
    }
}
