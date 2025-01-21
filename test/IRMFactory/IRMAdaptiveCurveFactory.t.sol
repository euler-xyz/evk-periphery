// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IFactory} from "../../src/BaseFactory/interfaces/IFactory.sol";
import {IRMAdaptiveCurve} from "../../src/IRM/IRMAdaptiveCurve.sol";
import {EulerIRMAdaptiveCurveFactory} from "../../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";

contract EulerIRMAdaptiveCurveFactoryTest is Test {
    int256 internal constant YEAR = int256(365.2425 days);
    EulerIRMAdaptiveCurveFactory factory;

    function setUp() public {
        factory = new EulerIRMAdaptiveCurveFactory();
    }

    function test_DeployBubblesUpErrors(
        int256 TARGET_UTILIZATION,
        int256 INITIAL_RATE_AT_TARGET,
        int256 MIN_RATE_AT_TARGET,
        int256 MAX_RATE_AT_TARGET,
        int256 CURVE_STEEPNESS,
        int256 ADJUSTMENT_SPEED
    ) public {
        try factory.deploy(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        ) returns (address) {} catch (bytes memory err) {
            // Errors are bubbled up
            vm.expectRevert(err);
            new IRMAdaptiveCurve(
                TARGET_UTILIZATION,
                INITIAL_RATE_AT_TARGET,
                MIN_RATE_AT_TARGET,
                MAX_RATE_AT_TARGET,
                CURVE_STEEPNESS,
                ADJUSTMENT_SPEED
            );
        }
    }

    function test_DeployIntegrity(
        address msgSender,
        uint256 blockTimestamp,
        int256 TARGET_UTILIZATION,
        int256 INITIAL_RATE_AT_TARGET,
        int256 MIN_RATE_AT_TARGET,
        int256 MAX_RATE_AT_TARGET,
        int256 CURVE_STEEPNESS,
        int256 ADJUSTMENT_SPEED
    ) public {
        TARGET_UTILIZATION = bound(TARGET_UTILIZATION, 0.001e18, 0.999e18);
        MIN_RATE_AT_TARGET = bound(MIN_RATE_AT_TARGET, 0.001e18 / YEAR, 10e18 / YEAR);
        MAX_RATE_AT_TARGET = bound(MAX_RATE_AT_TARGET, MIN_RATE_AT_TARGET, 10e18 / YEAR);
        INITIAL_RATE_AT_TARGET = bound(INITIAL_RATE_AT_TARGET, MIN_RATE_AT_TARGET, MAX_RATE_AT_TARGET);
        CURVE_STEEPNESS = bound(CURVE_STEEPNESS, 1.01e18, 100e18);
        ADJUSTMENT_SPEED = bound(ADJUSTMENT_SPEED, 2e18 / YEAR, 1000e18 / YEAR);
        blockTimestamp = bound(blockTimestamp, 1, type(uint96).max);

        vm.startPrank(msgSender);
        vm.warp(blockTimestamp);

        vm.expectEmit(false, true, true, true, address(factory));
        emit IFactory.ContractDeployed(address(0), msgSender, blockTimestamp);
        address irm = factory.deploy(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        assertEq(factory.getDeploymentsListLength(), 1);
        assertEq(factory.deployments(0), irm);
        assertTrue(factory.isValidDeployment(irm));
        (address deployer, uint96 deployedAt) = factory.getDeploymentInfo(irm);
        assertEq(deployer, msgSender);
        assertEq(deployedAt, blockTimestamp);

        assertEq(IRMAdaptiveCurve(irm).name(), "IRMAdaptiveCurve");
        assertEq(IRMAdaptiveCurve(irm).TARGET_UTILIZATION(), TARGET_UTILIZATION);
        assertEq(IRMAdaptiveCurve(irm).INITIAL_RATE_AT_TARGET(), INITIAL_RATE_AT_TARGET);
        assertEq(IRMAdaptiveCurve(irm).MIN_RATE_AT_TARGET(), MIN_RATE_AT_TARGET);
        assertEq(IRMAdaptiveCurve(irm).MAX_RATE_AT_TARGET(), MAX_RATE_AT_TARGET);
        assertEq(IRMAdaptiveCurve(irm).CURVE_STEEPNESS(), CURVE_STEEPNESS);
        assertEq(IRMAdaptiveCurve(irm).ADJUSTMENT_SPEED(), ADJUSTMENT_SPEED);
    }
}
