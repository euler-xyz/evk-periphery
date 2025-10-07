// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FeeFlowControllerEVK} from "../src/FeeFlow/FeeFlowControllerEVK.sol";

contract FeeFlow is ScriptUtils {
    function run() public broadcast returns (address feeFlowController) {
        string memory inputScriptFileName = "11_FeeFlow_input.json";
        string memory outputScriptFileName = "11_FeeFlow_output.json";
        string memory json = getScriptFile(inputScriptFileName);
        address evc = vm.parseJsonAddress(json, ".evc");
        uint256 initPrice = vm.parseJsonUint(json, ".initPrice");
        address paymentToken = vm.parseJsonAddress(json, ".paymentToken");
        address paymentReceiver = vm.parseJsonAddress(json, ".paymentReceiver");
        uint256 epochPeriod = vm.parseJsonUint(json, ".epochPeriod");
        uint256 priceMultiplier = vm.parseJsonUint(json, ".priceMultiplier");
        uint256 minInitPrice = vm.parseJsonUint(json, ".minInitPrice");
        address hookTarget = vm.parseJsonAddress(json, ".hookTarget");
        bytes4 hookTargetSelector = bytes4(vm.parseJsonBytes32(json, ".hookTargetSelector"));

        feeFlowController = execute(
            evc,
            initPrice,
            paymentToken,
            paymentReceiver,
            epochPeriod,
            priceMultiplier,
            minInitPrice,
            hookTarget,
            hookTargetSelector
        );

        string memory object;
        object = vm.serializeAddress("feeFlow", "feeFlowController", feeFlowController);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address evc,
        uint256 initPrice,
        address paymentToken,
        address paymentReceiver,
        uint256 epochPeriod,
        uint256 priceMultiplier,
        uint256 minInitPrice,
        address hookTarget,
        bytes4 hookTargetSelector
    ) public broadcast returns (address feeFlowController) {
        feeFlowController = execute(
            evc,
            initPrice,
            paymentToken,
            paymentReceiver,
            epochPeriod,
            priceMultiplier,
            minInitPrice,
            hookTarget,
            hookTargetSelector
        );
    }

    function execute(
        address evc,
        uint256 initPrice,
        address paymentToken,
        address paymentReceiver,
        uint256 epochPeriod,
        uint256 priceMultiplier,
        uint256 minInitPrice,
        address hookTarget,
        bytes4 hookTargetSelector
    ) public returns (address feeFlowController) {
        feeFlowController = address(
            new FeeFlowControllerEVK(
                evc,
                initPrice,
                paymentToken,
                paymentReceiver,
                epochPeriod,
                priceMultiplier,
                minInitPrice,
                hookTarget,
                hookTargetSelector
            )
        );
    }
}
