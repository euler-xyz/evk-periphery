// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {Errors} from "euler-price-oracle/lib/Errors.sol";

contract SanityCheckOracle is Script {
    function run() public view {
        address vault = vm.envOr("VAULT_ADDRESS", address(0));
        address[] memory vaults;

        if (vault == address(0)) {
            vaults = vm.envOr("VAULT_ADDRESS", ",", new address[](0));

            if (vaults.length == 0) {
                revert("no vaults provided");
            }

            for (uint256 i = 0; i < vaults.length; ++i) {
                OracleVerifier.verifyOracleConfig(vaults[i]);
            }
        } else {
            OracleVerifier.verifyOracleConfig(vault);
        }
    }
}

library OracleVerifier {
    function verifyOracleConfig(address vault) internal view {
        address asset = IEVault(vault).asset();
        address unitOfAccount = IEVault(vault).unitOfAccount();
        address oracle = IEVault(vault).oracle();
        address[] memory collaterals = IEVault(vault).LTVList();

        console.log("Checking oracle config for %s (%s)", IEVault(vault).symbol(), vault);
        if (collaterals.length == 0) {
            require(unitOfAccount == address(0), "unitOfAccount is not zero");
            require(oracle == address(0), "oracle is not zero");
            console.log("No oracle & unitOfAccount configured");
        } else {
            address unwrappedAsset = EulerRouter(oracle).resolvedVaults(asset);
            if (unwrappedAsset != address(0)) {
                require(
                    IEVault(asset).asset() == unwrappedAsset,
                    "resolved external vault asset is not equal to unwrapped asset"
                );
                require(
                    EulerRouter(oracle).getConfiguredOracle(asset, unitOfAccount) == address(0),
                    "asset short-circuiting adapter"
                );
            }

            OracleVerifier.verifyOracleCall(oracle, asset, unitOfAccount);

            for (uint256 i = 0; i < collaterals.length; ++i) {
                require(
                    IEVault(collaterals[i]).asset() == EulerRouter(oracle).resolvedVaults(collaterals[i]),
                    "collateral asset is not equal to unwrapped asset"
                );
                require(
                    EulerRouter(oracle).getConfiguredOracle(collaterals[i], unitOfAccount) == address(0),
                    "collateral short-circuiting adapter"
                );
                OracleVerifier.verifyOracleCall(oracle, collaterals[i], unitOfAccount);
            }
            console.log("Oracle config is valid\n");
        }
    }

    function verifyOracleCall(address oracle, address base, address quote) internal view {
        (, address finalBase,, address finalOracle) = EulerRouter(oracle).resolveOracle(0, base, quote);
        string memory oracleName =
            finalOracle == address(0) ? base == quote ? "Direct" : "Unknown" : IPriceOracle(finalOracle).name();
        string memory baseSymbol = IEVault(finalBase).symbol();
        string memory quoteSymbol = quote == address(840) ? "USD" : IEVault(quote).symbol();
        uint256 price;

        (bool success, bytes memory result) =
            oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (10 ** IEVault(base).decimals(), finalBase, quote)));

        if (success) {
            require(result.length == 32, "result length is not 32");
            price = abi.decode(result, (uint256));
            require(price > 0, "price is zero");
        } else {
            bytes4 err = bytes4(result);

            if (_strEq(oracleName, "PythOracle")) {
                require(err == Errors.PriceOracle_InvalidAnswer.selector, "error is not PriceOracle_InvalidAnswer");
            } else if (_strEq(oracleName, "RedstoneCoreOracle")) {
                require(err == Errors.PriceOracle_TooStale.selector, "error is not PriceOracle_TooStale");
            } else {
                require(false, "unexpected oracle error");
            }
        }

        console.log("%s price for %s/%s:", oracleName, baseSymbol, quoteSymbol);
        if (price == 0) {
            console.log("  needs an update");
        } else {
            uint256 scaledPrice = price * 1e6 / (quote == address(840) ? 1e18 : 10 ** IEVault(quote).decimals());
            uint256 integerPart = scaledPrice / 1e6;
            uint256 fractionalPart = scaledPrice % 1e6;
            string memory zeros = string(
                abi.encodePacked(
                    fractionalPart < 100000 ? "0" : "",
                    fractionalPart < 10000 ? "0" : "",
                    fractionalPart < 1000 ? "0" : "",
                    fractionalPart < 100 ? "0" : "",
                    fractionalPart < 10 ? "0" : ""
                )
            );
            console.log("  %s.%s%s", integerPart, zeros, fractionalPart);
        }
    }

    function _strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
