// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";

contract KinkIRM is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_KinkIRM_input.json";
        string memory outputScriptFileName = "04_KinkIRM_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address kinkIRMFactory = abi.decode(vm.parseJson(json, ".kinkIRMFactory"), (address));
        uint256 baseRate = abi.decode(vm.parseJson(json, ".baseRate"), (uint256));
        uint256 slope1 = abi.decode(vm.parseJson(json, ".slope1"), (uint256));
        uint256 slope2 = abi.decode(vm.parseJson(json, ".slope2"), (uint256));
        uint32 kink = abi.decode(vm.parseJson(json, ".kink"), (uint32));

        irm = execute(kinkIRMFactory, baseRate, slope1, slope2, kink);

        string memory object;
        object = vm.serializeAddress("irm", "irm", irm);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(address kinkIRMFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink)
        public
        broadcast
        returns (address irm)
    {
        irm = execute(kinkIRMFactory, baseRate, slope1, slope2, kink);
    }

    function execute(address kinkIRMFactory, uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink)
        public
        returns (address irm)
    {
        irm = EulerKinkIRMFactory(kinkIRMFactory).deploy(baseRate, slope1, slope2, kink);
    }
}

contract AdaptiveCurveIRM is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_AdaptiveCurveIRM_input.json";
        string memory outputScriptFileName = "04_AdaptiveCurveIRM_output.json";
        string memory json = getInputConfig(inputScriptFileName);
        address adaptiveCurveIRMFactory = abi.decode(vm.parseJson(json, ".adaptiveCurveIRMFactory"), (address));
        int256 targetUtilization = abi.decode(vm.parseJson(json, ".targetUtilization"), (int256));
        int256 initialRateAtTarget = abi.decode(vm.parseJson(json, ".initialRateAtTarget"), (int256));
        int256 minRateAtTarget = abi.decode(vm.parseJson(json, ".minRateAtTarget"), (int256));
        int256 maxRateAtTarget = abi.decode(vm.parseJson(json, ".maxRateAtTarget"), (int256));
        int256 curveSteepness = abi.decode(vm.parseJson(json, ".curveSteepness"), (int256));
        int256 adjustmentSpeed = abi.decode(vm.parseJson(json, ".adjustmentSpeed"), (int256));

        irm = execute(
            adaptiveCurveIRMFactory,
            targetUtilization,
            initialRateAtTarget,
            minRateAtTarget,
            maxRateAtTarget,
            curveSteepness,
            adjustmentSpeed
        );

        string memory object;
        object = vm.serializeAddress("irm", "irm", irm);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address adaptiveCurveIRMFactory,
        int256 targetUtilization,
        int256 initialRateAtTarget,
        int256 minRateAtTarget,
        int256 maxRateAtTarget,
        int256 curveSteepness,
        int256 adjustmentSpeed
    ) public broadcast returns (address irm) {
        irm = execute(
            adaptiveCurveIRMFactory,
            targetUtilization,
            initialRateAtTarget,
            minRateAtTarget,
            maxRateAtTarget,
            curveSteepness,
            adjustmentSpeed
        );
    }

    function execute(
        address adaptiveCurveIRMFactory,
        int256 targetUtilization,
        int256 initialRateAtTarget,
        int256 minRateAtTarget,
        int256 maxRateAtTarget,
        int256 curveSteepness,
        int256 adjustmentSpeed
    ) public returns (address irm) {
        irm = EulerIRMAdaptiveCurveFactory(adaptiveCurveIRMFactory).deploy(
            targetUtilization, initialRateAtTarget, minRateAtTarget, maxRateAtTarget, curveSteepness, adjustmentSpeed
        );
    }
}
