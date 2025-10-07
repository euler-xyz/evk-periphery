// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "evc/utils/EVCUtil.sol";

contract TestableMinimalEVCClient is EVCUtil {
    constructor(address evc_) EVCUtil(evc_) {}

    function getSender() external view returns (address) {
        return _msgSender();
    }
}
