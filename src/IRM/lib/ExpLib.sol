// SPDX-License-Identifier: MIT
// Copyright (c) 2023 Morpho Association
pragma solidity ^0.8.0;
/// @title ExpLib
/// @custom:contact security@euler.xyz
/// @author Adapted from Morpho Labs
/// (https://github.com/morpho-org/morpho-blue-irm/blob/a824ce06a53f45f12d0ffedb51abd756896b29fa/src/adaptive-curve-irm/libraries/ExpLib.sol)
/// @notice Library to approximate the exponential function.

library ExpLib {
    int256 internal constant WAD = 1e18;
    /// @dev ln(2).
    int256 internal constant LN_2_INT = 0.693147180559945309e18;
    /// @dev ln(1e-18).
    int256 internal constant LN_WEI_INT = -41.446531673892822312e18;
    /// @dev Above this bound, `wExp` is clipped to avoid overflowing when multiplied with 1e18.
    /// @dev This upper bound corresponds to: ln(type(int256).max / 1e36) (scaled by WAD, floored).
    int256 internal constant WEXP_UPPER_BOUND = 93.859467695000404319e18;
    /// @dev The value of wExp(`WEXP_UPPER_BOUND`).
    int256 internal constant WEXP_UPPER_VALUE = 57716089161558943949701069502944508345128.422502756744429568e18;
    /// @dev Returns an approximation of exp.

    function wExp(int256 x) internal pure returns (int256) {
        unchecked {
            // If x < ln(1e-18) then exp(x) < 1e-18 so it is rounded to zero.
            if (x < LN_WEI_INT) return 0;
            // `wExp` is clipped to avoid overflowing when multiplied with 1e18.
            if (x >= WEXP_UPPER_BOUND) return WEXP_UPPER_VALUE;
            // Decompose x as x = q * ln(2) + r with q an integer and -ln(2)/2 <= r <= ln(2)/2.
            // q = x / ln(2) rounded half toward zero.
            int256 roundingAdjustment = (x < 0) ? -(LN_2_INT / 2) : (LN_2_INT / 2);
            // Safe unchecked because x is bounded.
            int256 q = (x + roundingAdjustment) / LN_2_INT;
            // Safe unchecked because |q * ln(2) - x| <= ln(2)/2.
            int256 r = x - q * LN_2_INT;
            // Compute e^r with a 2nd-order Taylor polynomial.
            // Safe unchecked because |r| < 1e18.
            int256 expR = WAD + r + (r * r) / WAD / 2;
            // Return e^x = 2^q * e^r.
            if (q >= 0) return expR << uint256(q);
            else return expR >> uint256(-q);
        }
    }
}
