// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";
import {FeeFlowControllerUtil} from "../src/Util/FeeFlowControllerUtil.sol";

contract FeeFlow is ScriptUtils {
    function run() public broadcast returns (address feeFlowController, address feeFlowControllerUtil) {
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

        (feeFlowController, feeFlowControllerUtil) =
            execute(evc, initPrice, paymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice);

        string memory object;
        object = vm.serializeAddress("feeFlow", "feeFlowController", feeFlowController);
        object = vm.serializeAddress("feeFlow", "feeFlowControllerUtil", feeFlowControllerUtil);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address evc,
        uint256 initPrice,
        address paymentToken,
        address paymentReceiver,
        uint256 epochPeriod,
        uint256 priceMultiplier,
        uint256 minInitPrice
    ) public broadcast returns (address feeFlowController, address feeFlowControllerUtil) {
        (feeFlowController, feeFlowControllerUtil) =
            execute(evc, initPrice, paymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice);
    }

    function execute(
        address evc,
        uint256 initPrice,
        address paymentToken,
        address paymentReceiver,
        uint256 epochPeriod,
        uint256 priceMultiplier,
        uint256 minInitPrice
    ) public returns (address feeFlowController, address feeFlowControllerUtil) {
        feeFlowController = address(
            new FeeFlowController(
                evc, initPrice, paymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice
            )
        );
        feeFlowControllerUtil = address(new FeeFlowControllerUtil(address(feeFlowController)));
    }
}
