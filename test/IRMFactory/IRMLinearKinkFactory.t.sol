// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";

contract EulerKinkIRMFactoryTest is Test {
    // Factory policy: maximum per-second rate corresponding to 1000% APY.
    uint256 internal constant MAX_RATE = 75986279153383989049;
    uint256 internal constant UTILIZATION_SCALE = type(uint32).max;

    EulerKinkIRMFactory internal factory;

    function setUp() public {
        factory = new EulerKinkIRMFactory();
    }

    function testFuzz_DeployAcceptsRateExactlyAtLimit(uint32 kink, uint256 slope1Seed, uint256 slope2Seed) public {
        (uint256 baseRate, uint256 slope1, uint256 slope2) = curveAtLimit(kink, slope1Seed, slope2Seed);
        IRMLinearKink irm = IRMLinearKink(factory.deploy(baseRate, slope1, slope2, kink));

        assertEq(irm.computeInterestRateView(address(0), 0, UTILIZATION_SCALE), MAX_RATE);
        assertEq(irm.computeInterestRateView(address(0), UTILIZATION_SCALE, 0), baseRate);
        assertEq(
            irm.computeInterestRateView(address(0), UTILIZATION_SCALE - kink, kink), baseRate + uint256(kink) * slope1
        );
        assertTrue(factory.isValidDeployment(address(irm)));
        assertEq(factory.deployments(0), address(irm));
        assertEq(factory.getDeploymentsListLength(), 1);
    }

    function testFuzz_DeployRejectsRateOneUnitAboveLimit(uint32 kink, uint256 slope1Seed, uint256 slope2Seed) public {
        address previous = factory.deploy(0, 0, 0, 0);
        (uint256 baseRate, uint256 slope1, uint256 slope2) = curveAtLimit(kink, slope1Seed, slope2Seed);

        vm.expectRevert(EulerKinkIRMFactory.IRMFactory_ExcessiveInterestRate.selector);
        factory.deploy(baseRate + 1, slope1, slope2, kink);

        assertEq(factory.getDeploymentsListLength(), 1);
        assertEq(factory.deployments(0), previous);
        assertTrue(factory.isValidDeployment(previous));
    }

    function test_DeployChecksRateAboveKink() public {
        uint32 kink = type(uint32).max / 2;
        uint256 slope2 = MAX_RATE / (UTILIZATION_SCALE - kink) + 1;
        IRMLinearKink irm = new IRMLinearKink(0, 0, slope2, kink);

        // Checking only zero utilization and the kink would accept this curve.
        assertEq(irm.computeInterestRateView(address(0), UTILIZATION_SCALE, 0), 0);
        assertEq(irm.computeInterestRateView(address(0), UTILIZATION_SCALE - kink, kink), 0);
        assertGt(irm.computeInterestRateView(address(0), 0, UTILIZATION_SCALE), MAX_RATE);

        vm.expectRevert(EulerKinkIRMFactory.IRMFactory_ExcessiveInterestRate.selector);
        factory.deploy(0, 0, slope2, kink);
        assertEq(factory.getDeploymentsListLength(), 0);
    }

    function test_DeployBubblesUpRateOverflow() public {
        // No overflow at zero utilization or at kink=1, but overflow at full utilization.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        factory.deploy(0, type(uint256).max, 1, 1);
        assertEq(factory.getDeploymentsListLength(), 0);
    }

    function test_DeployAcceptsZeroKinkWithUnusedFirstSlope() public {
        IRMLinearKink irm = IRMLinearKink(factory.deploy(0, type(uint256).max, 1, 0));
        assertEq(irm.computeInterestRateView(address(0), UTILIZATION_SCALE, 0), 0);
        assertEq(irm.computeInterestRateView(address(0), 0, UTILIZATION_SCALE), UTILIZATION_SCALE);
    }

    function test_DeployAcceptsMaxKinkWithUnusedSecondSlope() public {
        IRMLinearKink irm = IRMLinearKink(factory.deploy(0, 1, type(uint256).max, type(uint32).max));
        assertEq(irm.computeInterestRateView(address(0), UTILIZATION_SCALE, 0), 0);
        assertEq(irm.computeInterestRateView(address(0), 0, UTILIZATION_SCALE), UTILIZATION_SCALE);
    }

    function curveAtLimit(uint32 kink, uint256 slope1Seed, uint256 slope2Seed)
        internal
        pure
        returns (uint256 baseRate, uint256 slope1, uint256 slope2)
    {
        // Allocate the rate budget across the two segments, keeping all arithmetic in range.
        slope1 = bound(slope1Seed, 0, MAX_RATE / UTILIZATION_SCALE);
        uint256 remainingRate = MAX_RATE - uint256(kink) * slope1;
        uint256 remainingUtilization = UTILIZATION_SCALE - kink;
        slope2 = remainingUtilization == 0 ? 0 : bound(slope2Seed, 0, remainingRate / remainingUtilization);
        baseRate = remainingRate - remainingUtilization * slope2;
    }
}
