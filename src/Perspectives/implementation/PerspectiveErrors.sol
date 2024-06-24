// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

/// @title PerspectiveErrors
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that defines the error codes for the perspectives.
abstract contract PerspectiveErrors {
    uint256 internal constant ERROR__FACTORY = 1 << 0;
    uint256 internal constant ERROR__IMPLEMENTATION = 1 << 1;
    uint256 internal constant ERROR__UPGRADABILITY = 1 << 2;
    uint256 internal constant ERROR__SINGLETON = 1 << 3;
    uint256 internal constant ERROR__NESTING = 1 << 4;
    uint256 internal constant ERROR__ORACLE_INVALID_ROUTER = 1 << 5;
    uint256 internal constant ERROR__ORACLE_GOVERNED_ROUTER = 1 << 6;
    uint256 internal constant ERROR__ORACLE_INVALID_FALLBACK = 1 << 7;
    uint256 internal constant ERROR__ORACLE_INVALID_ROUTER_CONFIG = 1 << 8;
    uint256 internal constant ERROR__ORACLE_INVALID_ADAPTER = 1 << 9;
    uint256 internal constant ERROR__UNIT_OF_ACCOUNT = 1 << 10;
    uint256 internal constant ERROR__CREATOR = 1 << 11;
    uint256 internal constant ERROR__GOVERNOR = 1 << 12;
    uint256 internal constant ERROR__FEE_RECEIVER = 1 << 13;
    uint256 internal constant ERROR__INTEREST_FEE = 1 << 14;
    uint256 internal constant ERROR__INTEREST_RATE_MODEL = 1 << 15;
    uint256 internal constant ERROR__SUPPLY_CAP = 1 << 16;
    uint256 internal constant ERROR__BORROW_CAP = 1 << 17;
    uint256 internal constant ERROR__HOOK_TARGET = 1 << 18;
    uint256 internal constant ERROR__HOOKED_OPS = 1 << 19;
    uint256 internal constant ERROR__CONFIG_FLAGS = 1 << 20;
    uint256 internal constant ERROR__NAME = 1 << 21;
    uint256 internal constant ERROR__SYMBOL = 1 << 22;
    uint256 internal constant ERROR__LIQUIDATION_DISCOUNT = 1 << 23;
    uint256 internal constant ERROR__LIQUIDATION_COOL_OFF_TIME = 1 << 24;
    uint256 internal constant ERROR__LTV_COLLATERAL_CONFIG_LENGTH = 1 << 25;
    uint256 internal constant ERROR__LTV_COLLATERAL_CONFIG_SEPARATION = 1 << 26;
    uint256 internal constant ERROR__LTV_COLLATERAL_CONFIG_BORROW = 1 << 27;
    uint256 internal constant ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION = 1 << 28;
    uint256 internal constant ERROR__LTV_COLLATERAL_RAMPING = 1 << 29;
    uint256 internal constant ERROR__LTV_COLLATERAL_RECOGNITION = 1 << 30;
}
