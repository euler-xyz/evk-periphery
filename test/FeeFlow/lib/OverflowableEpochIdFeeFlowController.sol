// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../../src/FeeFlow/FeeFlowControllerEVK.sol";

contract OverflowableEpochIdFeeFlowController is FeeFlowControllerEVK {
    constructor(
        address evc_,
        uint256 initPrice,
        address paymentToken_,
        address paymentReceiver_,
        uint256 epochPeriod_,
        uint256 priceMultiplier_,
        uint256 minInitPrice_,
        address hookTarget_,
        bytes memory hookCalldata_
    )
        FeeFlowControllerEVK(
            evc_,
            initPrice,
            paymentToken_,
            paymentReceiver_,
            epochPeriod_,
            priceMultiplier_,
            minInitPrice_,
            hookTarget_,
            hookCalldata_
        )
    {}

    function setEpochId(uint16 epochId) public {
        slot0.epochId = epochId;
    }
}
