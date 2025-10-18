// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils} from "./utils/ScriptUtils.s.sol";
import {FeeFlowControllerEVK} from "../src/FeeFlow/FeeFlowControllerEVK.sol";

contract FeeFlow is ScriptUtils {
    struct Input {
        address evc;
        uint256 initPrice;
        address paymentToken;
        address paymentReceiver;
        uint256 epochPeriod;
        uint256 priceMultiplier;
        uint256 minInitPrice;
        address oftAdapter;
        uint32 dstEid;
        address hookTarget;
        bytes4 hookTargetSelector;
    }

    function run() public broadcast returns (address feeFlowController) {
        string memory inputScriptFileName = "11_FeeFlow_input.json";
        string memory outputScriptFileName = "11_FeeFlow_output.json";
        string memory json = getScriptFile(inputScriptFileName);

        feeFlowController = execute(
            Input({
                evc: vm.parseJsonAddress(json, ".evc"),
                initPrice: vm.parseJsonUint(json, ".initPrice"),
                paymentToken: vm.parseJsonAddress(json, ".paymentToken"),
                paymentReceiver: vm.parseJsonAddress(json, ".paymentReceiver"),
                epochPeriod: vm.parseJsonUint(json, ".epochPeriod"),
                priceMultiplier: vm.parseJsonUint(json, ".priceMultiplier"),
                minInitPrice: vm.parseJsonUint(json, ".minInitPrice"),
                oftAdapter: vm.parseJsonAddress(json, ".oftAdapter"),
                dstEid: uint32(vm.parseJsonUint(json, ".dstEid")),
                hookTarget: vm.parseJsonAddress(json, ".hookTarget"),
                hookTargetSelector: bytes4(vm.parseJsonBytes32(json, ".hookTargetSelector"))
            })
        );

        string memory object;
        object = vm.serializeAddress("feeFlow", "feeFlowController", feeFlowController);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(Input memory input) public broadcast returns (address feeFlowController) {
        feeFlowController = execute(input);
    }

    function execute(Input memory input) public returns (address feeFlowController) {
        feeFlowController = address(
            new FeeFlowControllerEVK(
                input.evc,
                input.initPrice,
                input.paymentToken,
                input.paymentReceiver,
                input.epochPeriod,
                input.priceMultiplier,
                input.minInitPrice,
                input.oftAdapter,
                input.dstEid,
                input.hookTarget,
                input.hookTargetSelector
            )
        );
    }
}
