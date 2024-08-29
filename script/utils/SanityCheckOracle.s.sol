// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {Errors} from "euler-price-oracle/lib/Errors.sol";

contract SanityCheckOracle is Script {
    function run() public view {
        OracleVerifier.verifyOracleConfig(vm.envAddress("VAULT_ADDRESS"));
    }
}

library OracleVerifier {
    function verifyOracleConfig(address vault) internal view {
        address asset = IEVault(vault).asset();
        address unitOfAccount = IEVault(vault).unitOfAccount();
        address oracle = IEVault(vault).oracle();
        address[] memory collaterals = IEVault(vault).LTVList();

        if (collaterals.length == 0) {
            assert(unitOfAccount == address(0));
            assert(oracle == address(0));
        } else {
            OracleVerifier.verifyOracleCall(oracle, asset, unitOfAccount);

            for (uint256 i = 0; i < collaterals.length; ++i) {
                OracleVerifier.verifyOracleCall(oracle, collaterals[i], unitOfAccount);
            }
        }
    }

    function verifyOracleCall(address oracle, address base, address quote) internal view {
        (bool success, bytes memory result) = oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (0, base, quote)));

        if (success) {
            assert(result.length >= 32);
        } else {
            bytes4 err = bytes4(result);
            assert(err == Errors.PriceOracle_TooStale.selector || err == Errors.PriceOracle_InvalidAnswer.selector);
        }
    }
}
