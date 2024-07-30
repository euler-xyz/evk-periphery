// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {OP_MAX_VALUE} from "evk/EVault/shared/Constants.sol";
import {EmergencyAdmin} from "./EmergencyAdmin.sol";

/// @title VaultEmergencyAdmin
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Emergency admin for EVaults, allowing guardians to pause all vault operations
contract VaultEmergencyAdmin is EmergencyAdmin {
    constructor(address admin, address[] memory guardians) EmergencyAdmin(admin, guardians) {}

    function _emergency(address target) internal override {
        IEVault(target).setHookConfig(address(0), OP_MAX_VALUE - 1);
    }
}