// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {EulerKinkIRMFactory} from "../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerKinkyIRMFactory} from "../src/IRMFactory/EulerKinkyIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";

contract KinkIRMDeployer is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_KinkIRM_input.json";
        string memory outputScriptFileName = "04_KinkIRM_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address kinkIRMFactory = vm.parseJsonAddress(json, ".kinkIRMFactory");
        uint256 baseRate = vm.parseJsonUint(json, ".baseRate");
        uint256 slope1 = vm.parseJsonUint(json, ".slope1");
        uint256 slope2 = vm.parseJsonUint(json, ".slope2");
        uint32 kink = uint32(vm.parseJsonUint(json, ".kink"));

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

contract KinkyIRMDeployer is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_KinkIRM_input.json";
        string memory outputScriptFileName = "04_KinkIRM_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address kinkyIRMFactory = vm.parseJsonAddress(json, ".kinkyIRMFactory");
        uint256 baseRate = vm.parseJsonUint(json, ".baseRate");
        uint256 slope = vm.parseJsonUint(json, ".slope");
        uint256 shape = vm.parseJsonUint(json, ".shape");
        uint32 kink = uint32(vm.parseJsonUint(json, ".kink"));
        uint256 cutoff = vm.parseJsonUint(json, ".cutoff");

        irm = execute(kinkyIRMFactory, baseRate, slope, shape, kink, cutoff);

        string memory object;
        object = vm.serializeAddress("irm", "irm", irm);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address kinkyIRMFactory,
        uint256 baseRate,
        uint256 slope,
        uint256 shape,
        uint32 kink,
        uint256 cutoff
    ) public broadcast returns (address irm) {
        irm = execute(kinkyIRMFactory, baseRate, slope, shape, kink, cutoff);
    }

    function execute(
        address kinkyIRMFactory,
        uint256 baseRate,
        uint256 slope,
        uint256 shape,
        uint32 kink,
        uint256 cutoff
    ) public returns (address irm) {
        irm = EulerKinkyIRMFactory(kinkyIRMFactory).deploy(baseRate, slope, shape, kink, cutoff);
    }
}

contract AdaptiveCurveIRMDeployer is ScriptUtils {
    function run() public broadcast returns (address irm) {
        string memory inputScriptFileName = "04_AdaptiveCurveIRM_input.json";
        string memory outputScriptFileName = "04_AdaptiveCurveIRM_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address adaptiveCurveIRMFactory = vm.parseJsonAddress(json, ".adaptiveCurveIRMFactory");
        int256 targetUtilization = vm.parseJsonInt(json, ".targetUtilization");
        int256 initialRateAtTarget = vm.parseJsonInt(json, ".initialRateAtTarget");
        int256 minRateAtTarget = vm.parseJsonInt(json, ".minRateAtTarget");
        int256 maxRateAtTarget = vm.parseJsonInt(json, ".maxRateAtTarget");
        int256 curveSteepness = vm.parseJsonInt(json, ".curveSteepness");
        int256 adjustmentSpeed = vm.parseJsonInt(json, ".adjustmentSpeed");

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
