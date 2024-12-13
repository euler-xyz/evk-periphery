// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {IPriceOracle} from "euler-price-oracle/interfaces/IPriceOracle.sol";
import {OracleLens} from "./OracleLens.sol";
import {Utils} from "./Utils.sol";
import "./LensTypes.sol";

contract UtilsLens is Utils {
    OracleLens public immutable oracleLens;

    constructor(address _oracleLens) {
        oracleLens = OracleLens(_oracleLens);
    }

    function computeAPYs(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        external
        pure
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        return _computeAPYs(borrowSPY, cash, borrows, interestFee);
    }

    function calculateTimeToLiquidation(
        address liabilityVault,
        uint256 liabilityValue,
        address[] memory collaterals,
        uint256[] memory collateralValues
    ) external view returns (int256) {
        return _calculateTimeToLiquidation(liabilityVault, liabilityValue, collaterals, collateralValues);
    }

    function getControllerAssetPriceInfo(address controller, address asset)
        public
        view
        returns (AssetPriceInfo memory)
    {
        AssetPriceInfo memory result;

        result.timestamp = block.timestamp;

        result.oracle = IEVault(controller).oracle();
        result.asset = asset;
        result.unitOfAccount = IEVault(controller).unitOfAccount();

        result.amountIn = 10 ** _getDecimals(asset);

        if (result.oracle == address(0)) {
            result.queryFailure = true;
            return result;
        }

        (bool success, bytes memory data) = result.oracle.staticcall(
            abi.encodeCall(IPriceOracle.getQuote, (result.amountIn, asset, result.unitOfAccount))
        );

        if (success && data.length >= 32) {
            result.amountOutMid = abi.decode(data, (uint256));
        } else {
            result.queryFailure = true;
            result.queryFailureReason = data;
        }

        (success, data) = result.oracle.staticcall(
            abi.encodeCall(IPriceOracle.getQuotes, (result.amountIn, asset, result.unitOfAccount))
        );

        if (success && data.length >= 64) {
            (result.amountOutBid, result.amountOutAsk) = abi.decode(data, (uint256, uint256));
        } else {
            result.queryFailure = true;
        }

        return result;
    }

    function getAssetPriceInfo(address asset, address unitOfAccount) public view returns (AssetPriceInfo memory) {
        AssetPriceInfo memory result;

        result.timestamp = block.timestamp;

        result.asset = asset;
        result.unitOfAccount = unitOfAccount;

        result.amountIn = 10 ** _getDecimals(asset);

        address[] memory adapters = oracleLens.getValidAdapters(asset, unitOfAccount);
        uint256 amountIn = result.amountIn;

        if (adapters.length == 0) {
            (bool success, bytes memory data) =
                asset.staticcall(abi.encodeCall(IEVault(asset).convertToAssets, (amountIn)));

            if (success && data.length >= 32) {
                amountIn = abi.decode(data, (uint256));
                (success, data) = asset.staticcall(abi.encodeCall(IEVault(asset).asset, ()));

                if (success && data.length >= 32) {
                    asset = abi.decode(data, (address));
                    adapters = oracleLens.getValidAdapters(asset, unitOfAccount);
                }
            }
        }

        if (adapters.length == 0) {
            result.queryFailure = true;
            return result;
        }

        for (uint256 i = 0; i < adapters.length; ++i) {
            result.oracle = adapters[i];
            result.queryFailure = false;
            result.queryFailureReason = "";

            (bool success, bytes memory data) =
                result.oracle.staticcall(abi.encodeCall(IPriceOracle.getQuote, (amountIn, asset, unitOfAccount)));

            if (success && data.length >= 32) {
                result.amountOutMid = abi.decode(data, (uint256));
            } else {
                result.queryFailure = true;
                result.queryFailureReason = data;
            }

            (success, data) =
                result.oracle.staticcall(abi.encodeCall(IPriceOracle.getQuotes, (amountIn, asset, unitOfAccount)));

            if (success && data.length >= 64) {
                (result.amountOutBid, result.amountOutAsk) = abi.decode(data, (uint256, uint256));
            } else {
                result.queryFailure = true;
            }

            if (!result.queryFailure) break;
        }

        return result;
    }
}
