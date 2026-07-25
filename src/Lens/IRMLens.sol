// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";
import {IFactory} from "../BaseFactory/interfaces/IFactory.sol";
import {IIRMNamed} from "../IRM/interfaces/IIRMNamed.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IRMAdaptiveCurve} from "../IRM/IRMAdaptiveCurve.sol";
import {IRMLinearKinky} from "../IRM/IRMLinearKinky.sol";
import {IRMFixedCyclicalBinary} from "../IRM/IRMFixedCyclicalBinary.sol";
import {IRMFixedCyclicalBinaryMonthly} from "../IRM/IRMFixedCyclicalBinaryMonthly.sol";
import "./LensTypes.sol";

contract IRMLens is Utils {
    address public immutable kinkIRMFactory;
    address public immutable adaptiveCurveIRMFactory;
    address public immutable kinkyIRMFactory;
    address public immutable fixedCyclicalBinaryIRMFactory;

    constructor(
        address _kinkIRMFactory,
        address _adaptiveCurveIRMFactory,
        address _kinkyIRMFactory,
        address _fixedCyclicalBinaryIRMFactory
    ) {
        kinkIRMFactory = _kinkIRMFactory;
        adaptiveCurveIRMFactory = _adaptiveCurveIRMFactory;
        kinkyIRMFactory = _kinkyIRMFactory;
        fixedCyclicalBinaryIRMFactory = _fixedCyclicalBinaryIRMFactory;
    }

    function getInterestRateModelInfo(address irm) public view returns (InterestRateModelDetailedInfo memory) {
        InterestRateModelDetailedInfo memory result;

        if (irm == address(0)) {
            return result;
        }

        result.interestRateModel = irm;

        if (IFactory(kinkIRMFactory).isValidDeployment(irm)) {
            result.interestRateModelType = InterestRateModelType.KINK;
            result.interestRateModelParams = abi.encode(
                KinkIRMInfo({
                    baseRate: IRMLinearKink(irm).baseRate(),
                    slope1: IRMLinearKink(irm).slope1(),
                    slope2: IRMLinearKink(irm).slope2(),
                    kink: IRMLinearKink(irm).kink()
                })
            );
        } else if (IFactory(adaptiveCurveIRMFactory).isValidDeployment(irm)) {
            result.interestRateModelType = InterestRateModelType.ADAPTIVE_CURVE;
            result.interestRateModelParams = abi.encode(
                AdaptiveCurveIRMInfo({
                    targetUtilization: IRMAdaptiveCurve(irm).TARGET_UTILIZATION(),
                    initialRateAtTarget: IRMAdaptiveCurve(irm).INITIAL_RATE_AT_TARGET(),
                    minRateAtTarget: IRMAdaptiveCurve(irm).MIN_RATE_AT_TARGET(),
                    maxRateAtTarget: IRMAdaptiveCurve(irm).MAX_RATE_AT_TARGET(),
                    curveSteepness: IRMAdaptiveCurve(irm).CURVE_STEEPNESS(),
                    adjustmentSpeed: IRMAdaptiveCurve(irm).ADJUSTMENT_SPEED()
                })
            );
        } else if (IFactory(kinkyIRMFactory).isValidDeployment(irm)) {
            result.interestRateModelType = InterestRateModelType.KINKY;
            result.interestRateModelParams = abi.encode(
                KinkyIRMInfo({
                    baseRate: IRMLinearKinky(irm).baseRate(),
                    slope: IRMLinearKinky(irm).slope(),
                    shape: IRMLinearKinky(irm).shape(),
                    kink: IRMLinearKinky(irm).kink(),
                    cutoff: IRMLinearKinky(irm).cutoff()
                })
            );
        } else if (IFactory(fixedCyclicalBinaryIRMFactory).isValidDeployment(irm)) {
            result.interestRateModelType = InterestRateModelType.FIXED_CYCLICAL_BINARY;
            result.interestRateModelParams = abi.encode(
                FixedCyclicalBinaryIRMInfo({
                    primaryRate: IRMFixedCyclicalBinary(irm).primaryRate(),
                    secondaryRate: IRMFixedCyclicalBinary(irm).secondaryRate(),
                    primaryDuration: IRMFixedCyclicalBinary(irm).primaryDuration(),
                    secondaryDuration: IRMFixedCyclicalBinary(irm).secondaryDuration(),
                    startTimestamp: IRMFixedCyclicalBinary(irm).startTimestamp()
                })
            );
        } else {
            // Fallback: IRMs that self-identify via IIRMNamed do not need a dedicated factory to be typed.
            (bool success, bytes memory data) = irm.staticcall(abi.encodeCall(IIRMNamed.name, ()));
            string memory name = success && data.length >= 32 ? abi.decode(data, (string)) : "";

            if (_strEq(name, "IRMFixedCyclicalBinaryMonthly")) {
                result.interestRateModelType = InterestRateModelType.FIXED_CYCLICAL_BINARY_MONTHLY;
                result.interestRateModelParams = abi.encode(
                    FixedCyclicalBinaryMonthlyIRMInfo({
                        primaryRate: IRMFixedCyclicalBinaryMonthly(irm).primaryRate(),
                        secondaryRate: IRMFixedCyclicalBinaryMonthly(irm).secondaryRate(),
                        cycleStartDay: IRMFixedCyclicalBinaryMonthly(irm).cycleStartDay(),
                        secondaryDays: IRMFixedCyclicalBinaryMonthly(irm).secondaryDays()
                    })
                );
            }
        }

        return result;
    }
}
