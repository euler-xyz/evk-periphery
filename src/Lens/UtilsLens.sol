// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";

contract UtilsLens is Utils {
    function computeSupplySPY(uint256 borrowSPY, uint256 cash, uint256 borrows, uint256 interestFee)
        external
        pure
        returns (uint256)
    {
        return _computeSupplySPY(borrowSPY, cash, borrows, interestFee);
    }

    function computeAPYs(uint256 borrowSPY, uint256 supplySPY)
        external
        pure
        returns (uint256 borrowAPY, uint256 supplyAPY)
    {
        return _computeAPYs(borrowSPY, supplySPY);
    }

    function calculateTimeToLiquidation(
        address liabilityVault,
        uint256 liabilityValue,
        address[] memory collaterals,
        uint256[] memory collateralValues
    ) external view returns (int256) {
        return _calculateTimeToLiquidation(liabilityVault, liabilityValue, collaterals, collateralValues);
    }
}
