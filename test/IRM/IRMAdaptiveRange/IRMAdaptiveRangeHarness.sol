// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveRange} from "../../../src/IRM/IRMAdaptiveRange.sol";

contract IRMAdaptiveRangeHarness is Test {
    IRMAdaptiveRange[] internal irms;

    struct StateHistory {
        uint256 cash;
        uint256 borrows;
        uint256 utilization;
        uint256 rate;
        uint208 fullRate;
        uint48 timestamp;
        uint32 delay;
    }

    uint256 public numCalls;
    mapping(IRMAdaptiveRange => StateHistory[]) public history;

    function addIrm(IRMAdaptiveRange irm) external {
        irms.push(irm);
    }

    function getIrms() external view returns (IRMAdaptiveRange[] memory) {
        return irms;
    }

    function computeInterestRate(uint24 delay, uint96 cash, uint96 borrows) external {
        skip(delay);
        ++numCalls;

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveRange irm = irms[i];
            uint256 rate = irm.computeInterestRate(address(this), cash, borrows);
            (uint208 fullRate, uint48 timestamp) = irm.irState(address(this));
            uint256 totalAssets = uint256(cash) + borrows;
            uint256 utilization = totalAssets == 0 ? 0 : uint256(borrows) * 1e18 / totalAssets;
            history[irm].push(
                StateHistory({
                    cash: cash,
                    borrows: borrows,
                    utilization: utilization,
                    rate: rate,
                    fullRate: fullRate,
                    timestamp: timestamp,
                    delay: delay
                })
            );
        }
    }

    function nthCall(IRMAdaptiveRange irm, uint256 index) external view returns (StateHistory memory) {
        return history[irm][index];
    }
}
