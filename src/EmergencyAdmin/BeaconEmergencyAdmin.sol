// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EmergencyAdmin} from "./EmergencyAdmin.sol";
import {ReadOnlyProxy} from "./ReadOnlyProxy.sol";

/// @title BeaconEmergencyAdmin
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Emergency admin for the EVK beacon (factory), allowing pause guardians to upgrade the implementation to read only proxy
contract BeaconEmergencyAdmin is EmergencyAdmin {
    constructor(address admin, address[] memory guardians) EmergencyAdmin(admin, guardians) {}

    function _emergency(address target) internal override {
        address oldImplementation = GenericFactory(target).implementation();
        address readOnlyProxy = address(new ReadOnlyProxy(oldImplementation));
        GenericFactory(target).setImplementation(readOnlyProxy);
    }
}