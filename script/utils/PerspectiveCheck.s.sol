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
        PerspectiveVerifier.verifyPerspective(perspective, vault);
    }
}

library PerspectiveVerifier {
    function verifyPerspective(address perspective, address vault) internal {
        console.log("Checking %s perspective for %s (%s)", perspective, IEVault(vault).symbol(), vault);

        (bool success, bytes memory result) =
            perspective.call(abi.encodeCall(BasePerspective.perspectiveVerify, (vault, false)));

        if (success) {
            console.log("Vault verified correctly\n");
            return;
        }

        assembly {
            result := add(result, 4)
        }

        (,, uint256 code) = abi.decode(result, (address, address, uint256));

        if (code & FACTORY != 0) console.log("ERROR__FACTORY");
        if (code & IMPLEMENTATION != 0) console.log("ERROR__IMPLEMENTATION");
        if (code & UPGRADABILITY != 0) console.log("ERROR__UPGRADABILITY");
        if (code & SINGLETON != 0) console.log("ERROR__SINGLETON");
        if (code & NESTING != 0) console.log("ERROR__NESTING");
        if (code & ORACLE_INVALID_ROUTER != 0) console.log("ERROR__ORACLE_INVALID_ROUTER");
        if (code & ORACLE_GOVERNED_ROUTER != 0) console.log("ERROR__ORACLE_GOVERNED_ROUTER");
        if (code & ORACLE_INVALID_FALLBACK != 0) console.log("ERROR__ORACLE_INVALID_FALLBACK");
        if (code & ORACLE_INVALID_ROUTER_CONFIG != 0) console.log("ERROR__ORACLE_INVALID_ROUTER_CONFIG");
        if (code & ORACLE_INVALID_ADAPTER != 0) console.log("ERROR__ORACLE_INVALID_ADAPTER");
        if (code & UNIT_OF_ACCOUNT != 0) console.log("ERROR__UNIT_OF_ACCOUNT");
        if (code & CREATOR != 0) console.log("ERROR__CREATOR");
        if (code & GOVERNOR != 0) console.log("ERROR__GOVERNOR");
        if (code & FEE_RECEIVER != 0) console.log("ERROR__FEE_RECEIVER");
        if (code & INTEREST_FEE != 0) console.log("ERROR__INTEREST_FEE");
        if (code & INTEREST_RATE_MODEL != 0) console.log("ERROR__INTEREST_RATE_MODEL");
        if (code & SUPPLY_CAP != 0) console.log("ERROR__SUPPLY_CAP");
        if (code & BORROW_CAP != 0) console.log("ERROR__BORROW_CAP");
        if (code & HOOK_TARGET != 0) console.log("ERROR__HOOK_TARGET");
        if (code & HOOKED_OPS != 0) console.log("ERROR__HOOKED_OPS");
        if (code & CONFIG_FLAGS != 0) console.log("ERROR__CONFIG_FLAGS");
        if (code & NAME != 0) console.log("ERROR__NAME");
        if (code & SYMBOL != 0) console.log("ERROR__SYMBOL");
        if (code & LIQUIDATION_DISCOUNT != 0) console.log("ERROR__LIQUIDATION_DISCOUNT");
        if (code & LIQUIDATION_COOL_OFF_TIME != 0) console.log("ERROR__LIQUIDATION_COOL_OFF_TIME");
        if (code & LTV_COLLATERAL_CONFIG_LENGTH != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_LENGTH");
        if (code & LTV_COLLATERAL_CONFIG_SEPARATION != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_SEPARATION");
        if (code & LTV_COLLATERAL_CONFIG_BORROW != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_BORROW");
        if (code & LTV_COLLATERAL_CONFIG_LIQUIDATION != 0) console.log("ERROR__LTV_COLLATERAL_CONFIG_LIQUIDATION");
        if (code & LTV_COLLATERAL_RAMPING != 0) console.log("ERROR__LTV_COLLATERAL_RAMPING");
        if (code & LTV_COLLATERAL_RECOGNITION != 0) console.log("ERROR__LTV_COLLATERAL_RECOGNITION");
        console.log("Perspective check failed\n");
    }

    uint256 internal constant FACTORY = 1 << 0;
    uint256 internal constant IMPLEMENTATION = 1 << 1;
    uint256 internal constant UPGRADABILITY = 1 << 2;
    uint256 internal constant SINGLETON = 1 << 3;
    uint256 internal constant NESTING = 1 << 4;
    uint256 internal constant ORACLE_INVALID_ROUTER = 1 << 5;
    uint256 internal constant ORACLE_GOVERNED_ROUTER = 1 << 6;
    uint256 internal constant ORACLE_INVALID_FALLBACK = 1 << 7;
    uint256 internal constant ORACLE_INVALID_ROUTER_CONFIG = 1 << 8;
    uint256 internal constant ORACLE_INVALID_ADAPTER = 1 << 9;
    uint256 internal constant UNIT_OF_ACCOUNT = 1 << 10;
    uint256 internal constant CREATOR = 1 << 11;
    uint256 internal constant GOVERNOR = 1 << 12;
    uint256 internal constant FEE_RECEIVER = 1 << 13;
    uint256 internal constant INTEREST_FEE = 1 << 14;
    uint256 internal constant INTEREST_RATE_MODEL = 1 << 15;
    uint256 internal constant SUPPLY_CAP = 1 << 16;
    uint256 internal constant BORROW_CAP = 1 << 17;
    uint256 internal constant HOOK_TARGET = 1 << 18;
    uint256 internal constant HOOKED_OPS = 1 << 19;
    uint256 internal constant CONFIG_FLAGS = 1 << 20;
    uint256 internal constant NAME = 1 << 21;
    uint256 internal constant SYMBOL = 1 << 22;
    uint256 internal constant LIQUIDATION_DISCOUNT = 1 << 23;
    uint256 internal constant LIQUIDATION_COOL_OFF_TIME = 1 << 24;
    uint256 internal constant LTV_COLLATERAL_CONFIG_LENGTH = 1 << 25;
    uint256 internal constant LTV_COLLATERAL_CONFIG_SEPARATION = 1 << 26;
    uint256 internal constant LTV_COLLATERAL_CONFIG_BORROW = 1 << 27;
    uint256 internal constant LTV_COLLATERAL_CONFIG_LIQUIDATION = 1 << 28;
    uint256 internal constant LTV_COLLATERAL_RAMPING = 1 << 29;
    uint256 internal constant LTV_COLLATERAL_RECOGNITION = 1 << 30;
}
