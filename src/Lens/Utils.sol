// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {RPow} from "evk/EVault/shared/lib/RPow.sol";

abstract contract Utils {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 * 86400;
    uint256 internal constant ONE = 1e27;
    uint256 internal constant CONFIG_SCALE = 1e4;
    uint256 internal constant TTL_HS_ACCURACY = ONE / 1e4;
    int256 internal constant TTL_COMPUTATION_MIN = 0;
    int256 internal constant TTL_COMPUTATION_MAX = 400 * 1 days;
    int256 public constant TTL_INFINITY = type(int256).max;
    int256 public constant TTL_MORE_THAN_ONE_YEAR = type(int256).max - 1;
    int256 public constant TTL_LIQUIDATION = -1;
    int256 public constant TTL_ERROR = -2;

    function _strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @dev for tokens like MKR which return bytes32 on name() or symbol()
    function _getStringOrBytes32(address contractAddress, bytes4 selector) internal view returns (string memory) {
        (bool success, bytes memory result) = contractAddress.staticcall(abi.encodeWithSelector(selector));

        return (success && result.length != 0)
            ? result.length == 32 ? string(abi.encodePacked(result)) : abi.decode(result, (string))
            : "";
    }

    function _getDecimals(address contractAddress) internal view returns (uint8) {
        (bool success, bytes memory data) =
            contractAddress.staticcall(abi.encodeCall(IEVault(contractAddress).decimals, ()));

        return success && data.length >= 32 ? abi.decode(data, (uint8)) : 18;
    }

    function _getWETHAddress() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (block.chainid == 8453) {
            return 0x4200000000000000000000000000000000000006;
        } else if (block.chainid == 42161) {
            return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        } else {
            revert("Unsupported chain");
        }
    }

    function _computeSupplySPY(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        internal
        pure
        returns (uint256)
    {
        uint256 totalAssets = cash + borrows;
        return totalAssets == 0 ? 0 : borrowSPY * borrows * (CONFIG_SCALE - interestFee) / totalAssets / CONFIG_SCALE;
    }

    function _computeAPYs(uint256 borrowSPY, uint256 supplySPY)
        internal
        pure
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        bool overflowBorrow;
        bool overflowSupply;
        (borrowAPY, overflowBorrow) = RPow.rpow(borrowSPY + ONE, SECONDS_PER_YEAR, ONE);
        (supplyAPY, overflowSupply) = RPow.rpow(supplySPY + ONE, SECONDS_PER_YEAR, ONE);

        if (overflowBorrow || overflowSupply) return (0, 0);

        borrowAPY -= ONE;
        supplyAPY -= ONE;
    }

    function _calculateTimeToLiquidation(
        address liabilityVault,
        uint256 liabilityValue,
        address[] memory collaterals,
        uint256[] memory collateralValues
    ) internal view returns (int256) {
        // if there's no liability, time to liquidation is infinite
        if (liabilityValue == 0) return TTL_INFINITY;

        // get borrow interest rate
        uint256 liabilitySPY;
        {
            (bool success, bytes memory data) =
                liabilityVault.staticcall(abi.encodeCall(IEVault(liabilityVault).interestRate, ()));

            if (success && data.length >= 32) {
                liabilitySPY = abi.decode(data, (uint256));
            }
        }

        // get individual collateral interest rates and total collateral value
        uint256[] memory collateralSPYs = new uint256[](collaterals.length);
        uint256 collateralValue;
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            (bool success, bytes memory data) =
                collateral.staticcall(abi.encodeCall(IEVault(collateral).interestRate, ()));

            uint256 borrowSPY;
            if (success && data.length >= 32) {
                borrowSPY = abi.decode(data, (uint256));
            }

            if (borrowSPY > 0) {
                collateralSPYs[i] = _computeSupplySPY(
                    borrowSPY,
                    IEVault(collateral).cash(),
                    IEVault(collateral).totalBorrows(),
                    IEVault(collateral).interestFee()
                );
            }

            collateralValue += collateralValues[i];
        }

        // if liability is greater than or equal to collateral, the account is eligible for liquidation right away
        if (liabilityValue >= collateralValue) return TTL_LIQUIDATION;

        // if there's no borrow interest rate, time to liquidation is infinite
        if (liabilitySPY == 0) return TTL_INFINITY;

        int256 minTTL = TTL_COMPUTATION_MIN;
        int256 maxTTL = TTL_COMPUTATION_MAX;
        int256 ttl;

        // calculate time to liquidation using binary search
        while (true) {
            ttl = minTTL + (maxTTL - minTTL) / 2;

            // break if the search range is too small
            if (maxTTL <= minTTL + 1 days) break;
            if (ttl < 1 days) break;

            // calculate the liability interest accrued
            uint256 liabilityInterest;
            {
                (uint256 multiplier, bool overflow) = RPow.rpow(liabilitySPY + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                liabilityInterest = liabilityValue * multiplier / ONE - liabilityValue;
            }

            // calculate the collaterals interest accrued
            uint256 collateralInterest;
            for (uint256 i = 0; i < collaterals.length; ++i) {
                (uint256 multiplier, bool overflow) = RPow.rpow(collateralSPYs[i] + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                collateralInterest += collateralValues[i] * multiplier / ONE - collateralValues[i];
            }

            // calculate the health factor
            uint256 hs = (collateralValue + collateralInterest) * ONE / (liabilityValue + liabilityInterest);

            // if the collateral interest accrues fater than the liability interest, the account should never be
            // liquidated
            if (collateralInterest >= liabilityInterest) return TTL_INFINITY;

            // if the health factor is within the acceptable range, return the time to liquidation
            if (hs >= ONE && hs - ONE <= TTL_HS_ACCURACY) break;
            if (hs < ONE && ONE - hs <= TTL_HS_ACCURACY) break;

            // adjust the search range
            if (hs >= ONE) minTTL = ttl + 1 days;
            else maxTTL = ttl - 1 days;
        }

        return ttl > int256(SECONDS_PER_YEAR) ? TTL_MORE_THAN_ONE_YEAR : int256(ttl) / 1 days;
    }
}
