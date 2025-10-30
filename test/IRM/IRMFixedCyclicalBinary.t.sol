// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMFixedCyclicalBinary} from "../../src/IRM/IRMFixedCyclicalBinary.sol";
import {EulerFixedCyclicalBinaryIRMFactory} from "../../src/IRMFactory/EulerFixedCyclicalBinaryIRMFactory.sol";
import {MathTesting} from "../utils/MathTesting.sol";

import {console} from "forge-std/console.sol";

contract IRMFixedCyclicalBinaryTest is Test, MathTesting {
    IRMFixedCyclicalBinary irm;
    EulerFixedCyclicalBinaryIRMFactory factory;

    uint256 constant PRIMARY_RATE = 1;
    uint256 constant SECONDARY_RATE = 2;
    uint256 constant PRIMARY_DURATION = 28 days;
    uint256 constant SECONDARY_DURATION = 2 days;

    // corresponds to 1000% APY
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = 75986279153383989049;

    function setUp() public {
        irm = new IRMFixedCyclicalBinary(
            PRIMARY_RATE, SECONDARY_RATE, PRIMARY_DURATION, SECONDARY_DURATION, block.timestamp
        );

        factory = new EulerFixedCyclicalBinaryIRMFactory();
    }

    function test_OnlyVaultCanMutateIRMState() public {
        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        irm.computeInterestRate(address(1234), 5, 6);

        vm.prank(address(1234));
        irm.computeInterestRate(address(1234), 5, 6);
    }

    function test_ExpectRevertStartTimeInFuture() public {
        vm.expectRevert(IRMFixedCyclicalBinary.BadStartTimestamp.selector);
        new IRMFixedCyclicalBinary(
            PRIMARY_RATE, SECONDARY_RATE, PRIMARY_DURATION, SECONDARY_DURATION, block.timestamp + 1
        );
    }

    function test_ExpectRevertPrimaryDurationZero() public {
        vm.expectRevert(IRMFixedCyclicalBinary.BadDuration.selector);
        new IRMFixedCyclicalBinary(PRIMARY_RATE, SECONDARY_RATE, 0, SECONDARY_DURATION, block.timestamp);
    }

    function test_ExpectRevertSecondaryDurationZero() public {
        vm.expectRevert(IRMFixedCyclicalBinary.BadDuration.selector);
        new IRMFixedCyclicalBinary(PRIMARY_RATE, SECONDARY_RATE, PRIMARY_DURATION, 0, block.timestamp);
    }

    function test_ExpectRevertCycleDurationOverflows() public {
        vm.expectRevert(IRMFixedCyclicalBinary.BadDuration.selector);
        new IRMFixedCyclicalBinary(PRIMARY_RATE, SECONDARY_RATE, type(uint256).max - 1, 2, block.timestamp);
    }

    function test_RateAtDeployment() public view {
        assertEq(getIr(), PRIMARY_RATE);
    }

    function test_RateAtEndOfPrimaryPeriod() public {
        vm.warp(block.timestamp + PRIMARY_DURATION - 1);
        assertEq(getIr(), PRIMARY_RATE);

        vm.warp(block.timestamp + 1);
        assertEq(getIr(), PRIMARY_RATE);

        vm.warp(block.timestamp + 1);
        assertEq(getIr(), SECONDARY_RATE);
    }

    function test_RateAtEndOfCycle() public {
        vm.warp(block.timestamp + PRIMARY_DURATION + SECONDARY_DURATION - 1);
        assertEq(getIr(), SECONDARY_RATE);

        vm.warp(block.timestamp + 1);
        assertEq(getIr(), PRIMARY_RATE);
    }

    function test_CycleRates(uint256 timeElapsed, uint256 primaryDuration, uint256 secondaryDuration) public {
        timeElapsed = bound(timeElapsed, 0, 1000 days);
        primaryDuration = bound(primaryDuration, 1, 100 days);
        secondaryDuration = bound(secondaryDuration, 1, 100 days);

        irm =
            IRMFixedCyclicalBinary(factory.deploy(PRIMARY_RATE, SECONDARY_RATE, primaryDuration, secondaryDuration, 0));

        vm.warp(timeElapsed);

        uint256 cyclesElapsed = timeElapsed / (primaryDuration + secondaryDuration);

        if (timeElapsed - cyclesElapsed * (primaryDuration + secondaryDuration) <= primaryDuration) {
            assertEq(getIr(), PRIMARY_RATE);
        } else {
            assertEq(getIr(), SECONDARY_RATE);
        }
    }

    function test_ExpectRevertFactoryRateTooHigh() public {
        vm.expectRevert(EulerFixedCyclicalBinaryIRMFactory.IRMFactory_ExcessiveInterestRate.selector);
        factory.deploy(MAX_ALLOWED_INTEREST_RATE + 1, SECONDARY_RATE, PRIMARY_DURATION, SECONDARY_DURATION, 0);
        vm.expectRevert(EulerFixedCyclicalBinaryIRMFactory.IRMFactory_ExcessiveInterestRate.selector);
        factory.deploy(PRIMARY_RATE, MAX_ALLOWED_INTEREST_RATE + 1, PRIMARY_DURATION, SECONDARY_DURATION, 0);
    }

    function getIr() private view returns (uint256) {
        return irm.computeInterestRateView(address(1), 0, 0);
    }
}
