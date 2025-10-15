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
        address oftAdapter_,
        uint32 dstEid_,
        address hookTarget_,
        bytes4 hookSelector_
    )
        FeeFlowControllerEVK(
            evc_,
            initPrice,
            paymentToken_,
            paymentReceiver_,
            epochPeriod_,
            priceMultiplier_,
            minInitPrice_,
            oftAdapter_,
            dstEid_,
            hookTarget_,
            hookSelector_
        )
    {}

    function setEpochId(uint16 epochId) public {
        slot0.epochId = epochId;
    }
}
