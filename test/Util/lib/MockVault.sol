// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MockToken} from "../../FeeFlow/lib/MockToken.sol";

contract MockVault {
    MockToken underlying;
    address feeReceiver;
    uint256 feesAmount;
    constructor(MockToken underlying_, address feeReceiver_) {
        underlying = underlying_;
        feeReceiver = feeReceiver_;
    }

    function mockSetFeeAmount(uint256 newAmount) public {
        feesAmount = newAmount;
    }

    function convertFees() public {
        underlying.mint(feeReceiver, feesAmount);
    }

    function asset() external view returns(address) {
        return address(underlying);
    }
}