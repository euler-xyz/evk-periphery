// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Utils} from "./Utils.sol";
import {IFactory} from "../BaseFactory/interfaces/IFactory.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IRMAdaptiveCurve} from "../IRM/IRMAdaptiveCurve.sol";
import "./LensTypes.sol";

contract IRMLens is Utils {
    address public immutable kinkIRMFactory;
    address public immutable adaptiveCurveIRMFactory;

    constructor(address _kinkIRMFactory, address _adaptiveCurveIRMFactory) {
        kinkIRMFactory = _kinkIRMFactory;
        adaptiveCurveIRMFactory = _adaptiveCurveIRMFactory;
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
        }
        return result;
    }
}
