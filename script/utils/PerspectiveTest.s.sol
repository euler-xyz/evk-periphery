// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {BasePerspective} from "../../src/Perspectives/implementation/BasePerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";

contract PerspectiveTest is Script, PerspectiveErrors {
    function run() public {
        for (uint256 i = 0; i < 2; ++i) {
            console.log("");

            address perspective =
                i == 0 ? 0x5Dc3deE40528ae713D46105787bd6072Edf4e807 : 0xD85feb0d5200B23C4F6bBdc3dA0C9635dA49bA7f;

            (bool success, bytes memory ret) = perspective.call(
                abi.encodeCall(BasePerspective.perspectiveVerify, (0xBB8e17AdF854302A1E3CCf1991DF58Ef8d361EBE, false))
            );

            if (i == 0) {
                console.log("Escrow Perspective");
            } else {
                console.log("Cluster Perspective");
            }

            if (success) {
                console.log("Vault verified correctly");
                return;
            }

            assembly {
                ret := add(ret, 4)
            }

            (,, uint256 err) = abi.decode(ret, (address, address, uint256));

            if (err & ERROR__FACTORY != 0) console.log("ERROR__FACTORY");
            if (err & ERROR__IMPLEMENTATION != 0) console.log("ERROR__IMPLEMENTATION");
            if (err & ERROR__UPGRADABILITY != 0) console.log("ERROR__UPGRADABILITY");
            if (err & ERROR__SINGLETON != 0) console.log("ERROR__SINGLETON");
            if (err & ERROR__NESTING != 0) console.log("ERROR__NESTING");
            if (err & ERROR__ORACLE_INVALID_ROUTER != 0) console.log("ERROR__ORACLE_INVALID_ROUTER");
            if (err & ERROR__ORACLE_GOVERNED_ROUTER != 0) console.log("ERROR__ORACLE_GOVERNED_ROUTER");
            if (err & ERROR__ORACLE_INVALID_FALLBACK != 0) console.log("ERROR__ORACLE_INVALID_FALLBACK");
            if (err & ERROR__ORACLE_INVALID_ROUTER_CONFIG != 0) console.log("ERROR__ORACLE_INVALID_ROUTER_CONFIG");
            if (err & ERROR__ORACLE_INVALID_ADAPTER != 0) console.log("ERROR__ORACLE_INVALID_ADAPTER");
            if (err & ERROR__UNIT_OF_ACCOUNT != 0) console.log("ERROR__UNIT_OF_ACCOUNT");
            if (err & ERROR__CREATOR != 0) console.log("ERROR__CREATOR");
            if (err & ERROR__GOVERNOR != 0) console.log("ERROR__GOVERNOR");
            if (err & ERROR__FEE_RECEIVER != 0) console.log("ERROR__FEE_RECEIVER");
            if (err & ERROR__INTEREST_FEE != 0) console.log("ERROR__INTEREST_FEE");
            if (err & ERROR__INTEREST_RATE_MODEL != 0) console.log("ERROR__INTEREST_RATE_MODEL");
            if (err & ERROR__SUPPLY_CAP != 0) console.log("ERROR__SUPPLY_CAP");
            if (err & ERROR__BORROW_CAP != 0) console.log("ERROR__BORROW_CAP");
            if (err & ERROR__HOOK_TARGET != 0) console.log("ERROR__HOOK_TARGET");
            if (err & ERROR__HOOKED_OPS != 0) console.log("ERROR__HOOKED_OPS");
            if (err & ERROR__CONFIG_FLAGS != 0) console.log("ERROR__CONFIG_FLAGS");
            if (err & ERROR__NAME != 0) console.log("ERROR__NAME");
            if (err & ERROR__SYMBOL != 0) console.log("ERROR__SYMBOL");
            if (err & ERROR__LIQUIDATION_DISCOUNT != 0) console.log("ERROR__LIQUIDATION_DISCOUNT");
            if (err & ERROR__LIQUIDATION_COOL_OFF_TIME != 0) console.log("ERROR__LIQUIDATION_COOL_OFF_TIME");
            if (err & ERROR__LTV_COLLATERAL_CONFIG_LENGTH != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_LENGTH");
            if (err & ERROR__LTV_COLLATERAL_CONFIG_SEPARATION != 0) {
                console.log("ERROR__LTV_COLLATERAL_CONFIG_SEPARATION");
            }
            if (err & ERROR__LTV_COLLATERAL_CONFIG_BORROW != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_BORROW");
            if (err & ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION != 0) {
                console.log("ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION");
            }
            if (err & ERROR__LTV_COLLATERAL_RAMPING != 0) console.log("ERROR__LTV_COLLATERAL_RAMPING");
            if (err & ERROR__LTV_COLLATERAL_RECOGNITION != 0) console.log("ERROR__LTV_COLLATERAL_RECOGNITION");
        }
    }
}
