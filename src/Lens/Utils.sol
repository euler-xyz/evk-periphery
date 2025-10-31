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

    function getWETHAddress() internal view returns (address) {
        if (block.chainid == 1) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (
            block.chainid == 10 || block.chainid == 130 || block.chainid == 8453 || block.chainid == 1923
                || block.chainid == 480 || block.chainid == 57073 || block.chainid == 60808
        ) {
            return 0x4200000000000000000000000000000000000006;
        } else if (block.chainid == 56) {
            return 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
        } else if (block.chainid == 100) {
            return 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
        } else if (block.chainid == 137) {
            return 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        } else if (block.chainid == 146) {
            return 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b;
        } else if (block.chainid == 42161) {
            return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        } else if (block.chainid == 43114) {
            return 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
        } else if (block.chainid == 80094) {
            return 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
        } else {
            // bitcoin-specific and test networks
            if (
                block.chainid == 30 || block.chainid == 21000000 || block.chainid == 10143 || block.chainid == 80084
                    || block.chainid == 2390 || block.chainid == 998
            ) {
                return address(0);
            }
            // hyperEVM
            if (block.chainid == 999) {
                return address(0);
            }

            // TAC
            if (block.chainid == 239) {
                return address(0);
            }

            // Plasma
            if (block.chainid == 9745) {
                return address(0);
            }

            // Monad
            if (block.chainid == 143) {
                return address(0);
            }

            // Sepolia
            if (block.chainid == 11155111) {
                return address(0);
            }
        }

        revert("getWETHAddress: Unsupported chain");
    }

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

    function _computeAPYs(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        internal
        pure
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        uint256 totalAssets = cash + borrows;
        bool overflow;

        (borrowAPY, overflow) = RPow.rpow(borrowSPY + ONE, SECONDS_PER_YEAR, ONE);

        if (overflow) return (0, 0);

        borrowAPY -= ONE;
        supplyAPY =
            totalAssets == 0 ? 0 : borrowAPY * borrows * (CONFIG_SCALE - interestFee) / totalAssets / CONFIG_SCALE;
    }

    struct CollateralInfo {
        uint256 borrowSPY;
        uint256 borrows;
        uint256 totalAssets;
        uint256 interestFee;
        uint256 borrowInterest;
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
        CollateralInfo[] memory collateralInfos = new CollateralInfo[](collaterals.length);
        uint256 collateralValue;
        for (uint256 i = 0; i < collaterals.length; ++i) {
            address collateral = collaterals[i];

            (bool success, bytes memory data) =
                collateral.staticcall(abi.encodeCall(IEVault(collateral).interestRate, ()));

            if (success && data.length >= 32) {
                collateralInfos[i].borrowSPY = abi.decode(data, (uint256));
            }

            (success, data) = collateral.staticcall(abi.encodeCall(IEVault(collateral).totalBorrows, ()));

            if (success && data.length >= 32) {
                collateralInfos[i].borrows = abi.decode(data, (uint256));
            }

            (success, data) = collateral.staticcall(abi.encodeCall(IEVault(collateral).cash, ()));

            if (success && data.length >= 32) {
                collateralInfos[i].totalAssets = abi.decode(data, (uint256)) + collateralInfos[i].borrows;
            }

            (success, data) = collateral.staticcall(abi.encodeCall(IEVault(collateral).interestFee, ()));

            if (success && data.length >= 32) {
                collateralInfos[i].interestFee = abi.decode(data, (uint256));
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
            if (liabilitySPY > 0) {
                (uint256 multiplier, bool overflow) = RPow.rpow(liabilitySPY + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                liabilityInterest = liabilityValue * multiplier / ONE - liabilityValue;
            }

            // calculate the collaterals interest accrued
            uint256 collateralInterest;
            for (uint256 i = 0; i < collaterals.length; ++i) {
                if (collateralInfos[i].borrowSPY == 0 || collateralInfos[i].totalAssets == 0) continue;

                (uint256 multiplier, bool overflow) = RPow.rpow(collateralInfos[i].borrowSPY + ONE, uint256(ttl), ONE);

                if (overflow) return TTL_ERROR;

                collateralInfos[i].borrowInterest = collateralValues[i] * multiplier / ONE - collateralValues[i];

                collateralInterest += collateralInfos[i].borrowInterest * collateralInfos[i].borrows
                    * (CONFIG_SCALE - collateralInfos[i].interestFee) / collateralInfos[i].totalAssets / CONFIG_SCALE;
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
