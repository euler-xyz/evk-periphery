// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";

contract PerspectiveCheck is Script {
    function run() public {
        address perspective = vm.envAddress("PERSPECTIVE_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        PerspectiveVerifier.verifyPerspective(perspective, vault, 0, 0, true);
    }
}

library PerspectiveVerifier {
    function verifyPerspective(
        address perspective,
        address vault,
        uint256 expectedErrors,
        uint256 ignoredErrors,
        bool verbose
    ) internal {
        if (verbose) console.log("Checking %s perspective for %s (%s)", perspective, IEVault(vault).symbol(), vault);

        (bool success, bytes memory result) =
            perspective.call(abi.encodeCall(BasePerspective.perspectiveVerify, (vault, false)));

        if (success) {
            if (verbose) console.log("No errors detected\n");
            return;
        }

        assembly {
            result := add(result, 4)
        }

        (,, uint256 codes) = abi.decode(result, (address, address, uint256));

        string memory errors = "";
        if (codes & E__FACTORY != 0) errors = string.concat(errors, "E__FACTORY\n");
        if (codes & E__IMPLEMENTATION != 0) errors = string.concat(errors, "E__IMPLEMENTATION\n");
        if (codes & E__UPGRADABILITY != 0) errors = string.concat(errors, "E__UPGRADABILITY\n");
        if (codes & E__SINGLETON != 0) errors = string.concat(errors, "E__SINGLETON\n");
        if (codes & E__NESTING != 0) errors = string.concat(errors, "E__NESTING\n");
        if (codes & E__ORACLE_INVALID_ROUTER != 0) errors = string.concat(errors, "E__ORACLE_INVALID_ROUTER\n");
        if (codes & E__ORACLE_GOVERNED_ROUTER != 0) errors = string.concat(errors, "E__ORACLE_GOVERNED_ROUTER\n");
        if (codes & E__ORACLE_INVALID_FALLBACK != 0) errors = string.concat(errors, "E__ORACLE_INVALID_FALLBACK\n");
        if (codes & E__ORACLE_INVALID_ROUTER_CONFIG != 0) {
            errors = string.concat(errors, "E__ORACLE_INVALID_ROUTER_CONFIG\n");
        }
        if (codes & E__ORACLE_INVALID_ADAPTER != 0) errors = string.concat(errors, "E__ORACLE_INVALID_ADAPTER\n");
        if (codes & E__UNIT_OF_ACCOUNT != 0) errors = string.concat(errors, "E__UNIT_OF_ACCOUNT\n");
        if (codes & E__CREATOR != 0) errors = string.concat(errors, "E__CREATOR\n");
        if (codes & E__GOVERNOR != 0) errors = string.concat(errors, "E__GOVERNOR\n");
        if (codes & E__FEE_RECEIVER != 0) errors = string.concat(errors, "E__FEE_RECEIVER\n");
        if (codes & E__INTEREST_FEE != 0) errors = string.concat(errors, "E__INTEREST_FEE\n");
        if (codes & E__INTEREST_RATE_MODEL != 0) errors = string.concat(errors, "E__INTEREST_RATE_MODEL\n");
        if (codes & E__SUPPLY_CAP != 0) errors = string.concat(errors, "E__SUPPLY_CAP\n");
        if (codes & E__BORROW_CAP != 0) errors = string.concat(errors, "E__BORROW_CAP\n");
        if (codes & E__HOOK_TARGET != 0) errors = string.concat(errors, "E__HOOK_TARGET\n");
        if (codes & E__HOOKED_OPS != 0) errors = string.concat(errors, "E__HOOKED_OPS\n");
        if (codes & E__CONFIG_FLAGS != 0) errors = string.concat(errors, "E__CONFIG_FLAGS\n");
        if (codes & E__NAME != 0) errors = string.concat(errors, "E__NAME\n");
        if (codes & E__SYMBOL != 0) errors = string.concat(errors, "E__SYMBOL\n");
        if (codes & E__LIQUIDATION_DISCOUNT != 0) errors = string.concat(errors, "E__LIQUIDATION_DISCOUNT\n");
        if (codes & E__LIQUIDATION_COOL_OFF_TIME != 0) errors = string.concat(errors, "E__LIQUIDATION_COOL_OFF_TIME\n");
        if (codes & E__LTV_COLLATERAL_CONFIG_LENGTH != 0) {
            errors = string.concat(errors, "E__LTV_COLLATERAL_CONFIG_LENGTH\n");
        }
        if (codes & E__LTV_COLLATERAL_CONFIG_SEPARATION != 0) {
            errors = string.concat(errors, "E__LTV_COLLATERAL_CONFIG_SEPARATION\n");
        }
        if (codes & E__LTV_COLLATERAL_CONFIG_BORROW != 0) {
            errors = string.concat(errors, "E__LTV_COLLATERAL_CONFIG_BORROW\n");
        }
        if (codes & E__LTV_COLLATERAL_CONFIG_LIQUIDATION != 0) {
            errors = string.concat(errors, "E__LTV_COLLATERAL_CONFIG_LIQUIDATION\n");
        }
        if (codes & E__LTV_COLLATERAL_RAMPING != 0) errors = string.concat(errors, "E__LTV_COLLATERAL_RAMPING\n");
        if (codes & E__LTV_COLLATERAL_RECOGNITION != 0) {
            errors = string.concat(errors, "E__LTV_COLLATERAL_RECOGNITION\n");
        }

        if (expectedErrors != (codes & ~ignoredErrors)) {
            console.log("Errors detected:\n%s", errors);
            revert("Perspective check failed");
        }

        if (verbose) console.log("Only expected errors detected\n");
    }

    uint256 internal constant E__FACTORY = 1 << 0;
    uint256 internal constant E__IMPLEMENTATION = 1 << 1;
    uint256 internal constant E__UPGRADABILITY = 1 << 2;
    uint256 internal constant E__SINGLETON = 1 << 3;
    uint256 internal constant E__NESTING = 1 << 4;
    uint256 internal constant E__ORACLE_INVALID_ROUTER = 1 << 5;
    uint256 internal constant E__ORACLE_GOVERNED_ROUTER = 1 << 6;
    uint256 internal constant E__ORACLE_INVALID_FALLBACK = 1 << 7;
    uint256 internal constant E__ORACLE_INVALID_ROUTER_CONFIG = 1 << 8;
    uint256 internal constant E__ORACLE_INVALID_ADAPTER = 1 << 9;
    uint256 internal constant E__UNIT_OF_ACCOUNT = 1 << 10;
    uint256 internal constant E__CREATOR = 1 << 11;
    uint256 internal constant E__GOVERNOR = 1 << 12;
    uint256 internal constant E__FEE_RECEIVER = 1 << 13;
    uint256 internal constant E__INTEREST_FEE = 1 << 14;
    uint256 internal constant E__INTEREST_RATE_MODEL = 1 << 15;
    uint256 internal constant E__SUPPLY_CAP = 1 << 16;
    uint256 internal constant E__BORROW_CAP = 1 << 17;
    uint256 internal constant E__HOOK_TARGET = 1 << 18;
    uint256 internal constant E__HOOKED_OPS = 1 << 19;
    uint256 internal constant E__CONFIG_FLAGS = 1 << 20;
    uint256 internal constant E__NAME = 1 << 21;
    uint256 internal constant E__SYMBOL = 1 << 22;
    uint256 internal constant E__LIQUIDATION_DISCOUNT = 1 << 23;
    uint256 internal constant E__LIQUIDATION_COOL_OFF_TIME = 1 << 24;
    uint256 internal constant E__LTV_COLLATERAL_CONFIG_LENGTH = 1 << 25;
    uint256 internal constant E__LTV_COLLATERAL_CONFIG_SEPARATION = 1 << 26;
    uint256 internal constant E__LTV_COLLATERAL_CONFIG_BORROW = 1 << 27;
    uint256 internal constant E__LTV_COLLATERAL_CONFIG_LIQUIDATION = 1 << 28;
    uint256 internal constant E__LTV_COLLATERAL_RAMPING = 1 << 29;
    uint256 internal constant E__LTV_COLLATERAL_RECOGNITION = 1 << 30;
}
