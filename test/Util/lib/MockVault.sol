// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MockToken} from "../../FeeFlow/lib/MockToken.sol";

contract MockVault {
    MockToken underlying;
    address feeReceiver;
    uint256 public feesAmount;

    constructor(address underlying_, address feeReceiver_) {
        underlying = MockToken(underlying_);
        feeReceiver = feeReceiver_;
    }

    function mockSetFeeAmount(uint256 newAmount) public {
        feesAmount = newAmount;
    }

    function convertFees() public {
        if (underlying.balanceOf(address(this)) < feesAmount) {
            underlying.mint(address(this), feesAmount - underlying.balanceOf(address(this)));
        }
        underlying.transfer(feeReceiver, feesAmount);
        feesAmount = 0;
    }

    function redeem(uint256, address, address) public pure returns (uint256) {
        return 0;
    }

    function asset() external view returns (address) {
        return address(underlying);
    }
}
