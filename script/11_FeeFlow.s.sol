// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";

contract FeeFlow is ScriptUtils {
    function run() public broadcast returns (address feeFlowController) {
        string memory scriptFileName = "11_FeeFlow.json";
        string memory json = getInputConfig(scriptFileName);
        address evc = abi.decode(vm.parseJson(json, ".evc"), (address));
        uint256 initPrice = abi.decode(vm.parseJson(json, ".initPrice"), (uint256));
        address paymentToken = abi.decode(vm.parseJson(json, ".paymentToken"), (address));
        address paymentReceiver = abi.decode(vm.parseJson(json, ".paymentReceiver"), (address));
        uint256 epochPeriod = abi.decode(vm.parseJson(json, ".epochPeriod"), (uint256));
        uint256 priceMultiplier = abi.decode(vm.parseJson(json, ".priceMultiplier"), (uint256));
        uint256 minInitPrice = abi.decode(vm.parseJson(json, ".minInitPrice"), (uint256));

        feeFlowController =
            execute(evc, initPrice, paymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice);

        string memory object;
        object = vm.serializeAddress("feeFlow", "feeFlowController", feeFlowController);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/output/", scriptFileName));
    }

    function deploy(
        address evc,
        uint256 initPrice,
        address paymentToken,
        address paymentReceiver,
        uint256 epochPeriod,
        uint256 priceMultiplier,
        uint256 minInitPrice
    ) public broadcast returns (address feeFlowController) {
        feeFlowController =
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
    ) public returns (address feeFlowController) {
        feeFlowController = address(
            new FeeFlowController(
                evc, initPrice, paymentToken, paymentReceiver, epochPeriod, priceMultiplier, minInitPrice
            )
        );
    }
}
