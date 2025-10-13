// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OFTFeeCollector} from "../../../src/OFT/OFTFeeCollector.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract OFTFeeCollectorHarness is OFTFeeCollector {
    constructor(address admin, address feeToken) OFTFeeCollector(admin, feeToken) {}
    
    function harnessSetFeeToken(address newFeeToken) public {
        feeToken = IERC20(newFeeToken);
    }
}