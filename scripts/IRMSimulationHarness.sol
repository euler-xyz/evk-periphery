// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";

contract IRMSimulationHarness is Test {
    address internal vault;
    IIRM internal irm;

    struct State {
        uint256 timestamp;
        uint256 cash;
        uint256 borrows;
        uint256 rate;
    }

    State[] internal states;

    function useIRM(IIRM _irm) public returns (IRMSimulationHarness) {
        irm = _irm;
        return this;
    }

    function begin(uint256 seed) public returns (IRMSimulationHarness) {
        vault = address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, seed)))));
        return this;
    }

    function simulate(uint256 delay, uint256 cash, uint256 borrows) public returns (IRMSimulationHarness) {
        skip(delay);
        vm.prank(vault);
        uint256 rate = irm.computeInterestRate(vault, cash, borrows);
        states.push(State({timestamp: block.timestamp, cash: cash, borrows: borrows, rate: rate}));
        return this;
    }

    function dumpToCsv(string memory path) public returns (IRMSimulationHarness) {
        string memory titleLine = "timestamp,cash,borrows,rate";
        vm.writeLine(path, titleLine);
        for (uint256 i = 0; i < states.length; ++i) {
            State memory state = states[i];
            string memory line = string.concat(
                vm.toString(state.timestamp),
                ",",
                vm.toString(state.cash),
                ",",
                vm.toString(state.borrows),
                ",",
                vm.toString(state.rate)
            );
            vm.writeLine(path, line);
        }

        delete irm;
        delete states;
        return this;
    }
}
