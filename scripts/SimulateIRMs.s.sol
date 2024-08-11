// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMSimulationHarness} from "./IRMSimulationHarness.sol";
import {IRMAdaptiveLinearKink} from "../src/IRM/IRMAdaptiveLinearKink.sol";

contract SimulateIRMs is Script, IRMSimulationHarness {
    uint256 internal constant SEED = 2718;

    function scenario1() public {
        IRMAdaptiveLinearKink irmAdaptiveCurve = new IRMAdaptiveLinearKink(
            0.9 ether,
            0.04 ether / int256(365 days),
            0.001 ether / int256(365 days),
            2.0 ether / int256(365 days),
            4 ether,
            50 ether / int256(365 days)
        );

        useIRM(irmAdaptiveCurve);
        begin(SEED);
        simulate(0, 1e18, 9e18);
        simulate(3600, 0.9e18, 9.1e18);
        simulate(3600, 0.8e18, 9.2e18);
        simulate(3600, 0.7e18, 9.3e18);
        dumpToCsv("simulationResult.csv");
    }

    function run() public {
        scenario1();
    }
}
