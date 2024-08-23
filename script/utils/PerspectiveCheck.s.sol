// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";

contract PerspectiveCheck is Script, PerspectiveErrors {
    function run() public {
        address perspective = vm.envAddress("PERSPECTIVE_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");

        (bool success, bytes memory result) =
            perspective.call(abi.encodeCall(BasePerspective.perspectiveVerify, (vault, false)));

        if (success) {
            console.log("Vault verified correctly");
            return;
        }

        assembly {
            result := add(result, 4)
        }

        (,, uint256 code) = abi.decode(result, (address, address, uint256));

        if (code & ERROR__FACTORY != 0) console.log("ERROR__FACTORY");
        if (code & ERROR__IMPLEMENTATION != 0) console.log("ERROR__IMPLEMENTATION");
        if (code & ERROR__UPGRADABILITY != 0) console.log("ERROR__UPGRADABILITY");
        if (code & ERROR__SINGLETON != 0) console.log("ERROR__SINGLETON");
        if (code & ERROR__NESTING != 0) console.log("ERROR__NESTING");
        if (code & ERROR__ORACLE_INVALID_ROUTER != 0) console.log("ERROR__ORACLE_INVALID_ROUTER");
        if (code & ERROR__ORACLE_GOVERNED_ROUTER != 0) console.log("ERROR__ORACLE_GOVERNED_ROUTER");
        if (code & ERROR__ORACLE_INVALID_FALLBACK != 0) console.log("ERROR__ORACLE_INVALID_FALLBACK");
        if (code & ERROR__ORACLE_INVALID_ROUTER_CONFIG != 0) console.log("ERROR__ORACLE_INVALID_ROUTER_CONFIG");
        if (code & ERROR__ORACLE_INVALID_ADAPTER != 0) console.log("ERROR__ORACLE_INVALID_ADAPTER");
        if (code & ERROR__UNIT_OF_ACCOUNT != 0) console.log("ERROR__UNIT_OF_ACCOUNT");
        if (code & ERROR__CREATOR != 0) console.log("ERROR__CREATOR");
        if (code & ERROR__GOVERNOR != 0) console.log("ERROR__GOVERNOR");
        if (code & ERROR__FEE_RECEIVER != 0) console.log("ERROR__FEE_RECEIVER");
        if (code & ERROR__INTEREST_FEE != 0) console.log("ERROR__INTEREST_FEE");
        if (code & ERROR__INTEREST_RATE_MODEL != 0) console.log("ERROR__INTEREST_RATE_MODEL");
        if (code & ERROR__SUPPLY_CAP != 0) console.log("ERROR__SUPPLY_CAP");
        if (code & ERROR__BORROW_CAP != 0) console.log("ERROR__BORROW_CAP");
        if (code & ERROR__HOOK_TARGET != 0) console.log("ERROR__HOOK_TARGET");
        if (code & ERROR__HOOKED_OPS != 0) console.log("ERROR__HOOKED_OPS");
        if (code & ERROR__CONFIG_FLAGS != 0) console.log("ERROR__CONFIG_FLAGS");
        if (code & ERROR__NAME != 0) console.log("ERROR__NAME");
        if (code & ERROR__SYMBOL != 0) console.log("ERROR__SYMBOL");
        if (code & ERROR__LIQUIDATION_DISCOUNT != 0) console.log("ERROR__LIQUIDATION_DISCOUNT");
        if (code & ERROR__LIQUIDATION_COOL_OFF_TIME != 0) console.log("ERROR__LIQUIDATION_COOL_OFF_TIME");
        if (code & ERROR__LTV_COLLATERAL_CONFIG_LENGTH != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_LENGTH");
        if (code & ERROR__LTV_COLLATERAL_CONFIG_SEPARATION != 0) {
            console.log("ERROR__LTV_COLLATERAL_CONFIG_SEPARATION");
        }
        if (code & ERROR__LTV_COLLATERAL_CONFIG_BORROW != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_BORROW");
        if (code & ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION != 0) {
            console.log("ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION");
        }
        if (code & ERROR__LTV_COLLATERAL_RAMPING != 0) console.log("ERROR__LTV_COLLATERAL_RAMPING");
        if (code & ERROR__LTV_COLLATERAL_RECOGNITION != 0) console.log("ERROR__LTV_COLLATERAL_RECOGNITION");
    }
}
