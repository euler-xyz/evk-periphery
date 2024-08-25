// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";
import {ExpLib} from "../../../src/IRM/lib/ExpLib.sol";
import {
    AdaptiveCurveIrm,
    MarketParams,
    Market,
    ConstantsLib,
    Id,
    ExpLib as ExpLibRef
} from "morpho-blue-irm/adaptive-curve-irm/AdaptiveCurveIrm.sol";

contract IRMAdaptiveCurveDiffTest is Test {
    address internal constant VAULT = address(0x1234);
    address internal constant MORPHO = address(0x2345);
    uint256 internal constant NUM_INTERACTIONS = 50;

    /// @dev Verify that IRMAdaptiveCurve is equivalent to the reference AdaptiveCurveIrm.
    /// forge-config: default.fuzz.runs = 1000
    function test_DiffIRMAdaptiveCurveAgainstReference(uint256 seed) public {
        // Deploy IRMAdaptiveCurve with Morpho constants.
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            ConstantsLib.TARGET_UTILIZATION,
            ConstantsLib.INITIAL_RATE_AT_TARGET,
            ConstantsLib.MIN_RATE_AT_TARGET,
            ConstantsLib.MAX_RATE_AT_TARGET,
            ConstantsLib.CURVE_STEEPNESS,
            ConstantsLib.ADJUSTMENT_SPEED
        );

        AdaptiveCurveIrm irmRef = new AdaptiveCurveIrm(MORPHO);

        // Simulate interactions.
        for (uint256 i = 0; i < NUM_INTERACTIONS; ++i) {
            // Randomize utilization rate and time passed.
            (uint256 cash, uint256 borrows) = getCashAndBorrowsAtUtilizationRate(
                bound(uint256(keccak256(abi.encodePacked("utilizationRate", seed, i))), 0, 1e18)
            );
            uint256 timeDelta = bound(uint256(keccak256(abi.encodePacked("timeDelta", seed, i))), 0, 30 days);

            // We update the irms with a random utilization and random delta time.
            MarketParams memory marketParams;
            Market memory market;
            market.lastUpdate = uint128(block.timestamp);
            market.totalSupplyAssets = uint128(cash + borrows);
            market.totalBorrowAssets = uint128(borrows);

            skip(timeDelta);
            vm.startPrank(VAULT);
            uint256 rate = irm.computeInterestRate(VAULT, cash, borrows);
            uint256 rateAtTarget = irm.computeRateAtTargetView(VAULT, cash, borrows);
            vm.startPrank(MORPHO);
            uint256 rateRef = irmRef.borrowRate(marketParams, market);
            int256 rateAtTargetRef = irmRef.rateAtTarget(id(marketParams));

            assertEq(rate, rateRef * 1e9);
            assertEq(rateAtTarget, uint256(rateAtTargetRef * 1e9));
        }
    }

    /// @dev Verify that the exp function in IRMAdaptiveCurve is equivalent to the reference exp function.
    /// forge-config: default.fuzz.runs = 100000
    function test_DiffExpAgainstReference(int256 x) public pure {
        int256 result = ExpLib.wExp(x);
        int256 resultRef = ExpLibRef.wExp(x);

        assertEq(result, resultRef);
    }

    function getCashAndBorrowsAtUtilizationRate(uint256 utilizationRate) internal pure returns (uint256, uint256) {
        if (utilizationRate == 0) return (0, 0);
        if (utilizationRate == 1e18) return (0, 1e18);

        uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
        return (1e18, borrows);
    }

    /// @notice Returns the id of the market `marketParams`.
    function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(marketParams, 160)
        }
    }
}
