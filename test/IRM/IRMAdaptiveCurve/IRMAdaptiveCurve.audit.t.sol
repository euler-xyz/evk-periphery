// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";
import {ExpLib} from "../../../src/IRM/lib/ExpLib.sol";
import {
    AdaptiveCurveIrm,
    ConstantsLib,
    ExpLib as ExpLibRef,
    Id,
    Market,
    MarketParams,
    MarketParamsLib
} from "morpho-blue-irm/adaptive-curve-irm/AdaptiveCurveIrm.sol";

contract IRMAdaptiveCurveAuditTest is Test {
    using MarketParamsLib for MarketParams;

    address internal constant VAULT = address(0x1234);
    address internal constant MORPHO = address(0x2345);
    uint256 internal constant NUM_INTERACTIONS = 50;

    function test_Morpho() public {
        AdaptiveCurveIrm irmRef = new AdaptiveCurveIrm(MORPHO);

        uint256 rate;
        vm.startPrank(MORPHO);

        // t = 0
        MarketParams memory marketParams;
        Market memory market;
        market.lastUpdate = uint128(block.timestamp);
        market.totalSupplyAssets = 0;
        market.totalBorrowAssets = 0;

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=0:", rate);

        // t = 1 supply
        skip(1 days);

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=1:", rate);

        market.lastUpdate = uint128(block.timestamp);
        market.totalSupplyAssets = 100;
        market.totalBorrowAssets = 0;

        // t = 2 borrow
        skip(7 days);

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=2:", rate);

        market.lastUpdate = uint128(block.timestamp);
        market.totalSupplyAssets = 100;
        market.totalBorrowAssets = 95;

        // t = 3 accrue
        skip(1 days);

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=3:", rate);

        market.lastUpdate = uint128(block.timestamp);

        // t = 4 unwind
        skip(1 days);

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=4:", rate);

        market.lastUpdate = uint128(block.timestamp);
        market.totalSupplyAssets = 100;
        market.totalBorrowAssets = 0;

        // t = 5 accrue
        skip(1 days);

        rate = irmRef.borrowRate(marketParams, market);
        console.log("T=5:", rate);

        market.lastUpdate = uint128(block.timestamp);
    }

    function test_Euler() public {
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            ConstantsLib.TARGET_UTILIZATION,
            ConstantsLib.INITIAL_RATE_AT_TARGET,
            ConstantsLib.MIN_RATE_AT_TARGET,
            ConstantsLib.MAX_RATE_AT_TARGET,
            ConstantsLib.CURVE_STEEPNESS,
            ConstantsLib.ADJUSTMENT_SPEED
        );

        uint256 rate;
        vm.startPrank(VAULT);

        // t = 0 init
        rate = irm.computeInterestRate(VAULT, 0, 0);
        console.log("T=0:", rate);

        // t = 1 supply
        skip(1 days);

        rate = irm.computeInterestRate(VAULT, 100, 0);
        console.log("T=1:", rate);

        // t = 2 borrow
        skip(7 days);

        rate = irm.computeInterestRate(VAULT, 5, 95);
        console.log("T=2:", rate);

        // t = 3 accrue
        skip(1 days);

        rate = irm.computeInterestRate(VAULT, 5, 95);
        console.log("T=3:", rate);

        // t = 4 unwind
        skip(1 days);

        rate = irm.computeInterestRate(VAULT, 100, 0);
        console.log("T=4:", rate);

        // t = 5 accrue
        skip(1 days);

        rate = irm.computeInterestRate(VAULT, 100, 0);
        console.log("T=5:", rate);
    }

    function test_diffWithEuler() public {
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            ConstantsLib.TARGET_UTILIZATION,
            ConstantsLib.INITIAL_RATE_AT_TARGET,
            ConstantsLib.MIN_RATE_AT_TARGET,
            ConstantsLib.MAX_RATE_AT_TARGET,
            ConstantsLib.CURVE_STEEPNESS,
            ConstantsLib.ADJUSTMENT_SPEED
        );

        //init at 0% utilization
        uint256 cash = 10e18;
        uint256 borrow = 0;
        uint256 eulerRate = irm.computeInterestRate(address(this), cash, borrow); //Euler irm is called post borrow

        skip(7 days);

        //Euler
        //new 9e borrow
        cash -= 9e18;
        borrow += 9e18;
        eulerRate = irm.computeInterestRate(address(this), cash, borrow); //Euler irm is called post borrow
        emit log_uint(cash);
        emit log_uint(borrow);
        emit log_uint(eulerRate);

        skip(3 days);

        //user repay half
        borrow += borrow * eulerRate * 7 days / 1e27; //accrue first
        cash += borrow / 2;
        borrow /= 2;
        eulerRate = irm.computeInterestRate(address(this), cash, borrow); //Euler irm is called post borrow
        emit log_uint(cash);
        emit log_uint(borrow);
        emit log_uint(eulerRate);
        emit log_uint(cash + borrow);
    }

    function test_diffWithMorpho() public {
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            ConstantsLib.TARGET_UTILIZATION,
            ConstantsLib.INITIAL_RATE_AT_TARGET,
            ConstantsLib.MIN_RATE_AT_TARGET,
            ConstantsLib.MAX_RATE_AT_TARGET,
            ConstantsLib.CURVE_STEEPNESS,
            ConstantsLib.ADJUSTMENT_SPEED
        );

        //init at 0% utilization
        uint256 cash = 10e18;
        uint256 borrow = 0;
        uint256 morphoRate = irm.computeInterestRate(address(this), cash, borrow); //init

        skip(7 days);

        //Euler
        //new 9e borrow
        morphoRate = irm.computeInterestRate(address(this), cash, borrow); //Morpho irm is called pre borrow
        cash -= 9e18;
        borrow += 9e18;
        emit log_uint(cash);
        emit log_uint(borrow);
        emit log_uint(morphoRate);

        skip(3 days);

        //user repay half
        morphoRate = irm.computeInterestRate(address(this), cash, borrow);
        borrow += borrow * morphoRate * 7 days / 1e27; //accrue first
        cash += borrow / 2;
        borrow /= 2;
        emit log_uint(cash);
        emit log_uint(borrow);
        emit log_uint(morphoRate);
        emit log_uint(cash + borrow);
    }
}
