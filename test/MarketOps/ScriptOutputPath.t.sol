// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ScriptExtended} from "../../script/utils/ScriptExtended.s.sol";

contract ScriptOutputPathHarness is ScriptExtended {
    function resolveOutputDir(string memory path) external view returns (string memory) {
        return resolveScriptOutputDirPath(path);
    }

    function resolveOutputFile(string memory path, string memory fileName) external view returns (string memory) {
        return string.concat(resolveScriptOutputDirPath(path), "/", fileName);
    }
}

contract ScriptOutputPathTest is Test {
    ScriptOutputPathHarness private harness;

    function setUp() public {
        harness = new ScriptOutputPathHarness();
    }

    function testDefaultsToScriptDirectory() public view {
        assertEq(harness.resolveOutputDir(""), string.concat(vm.projectRoot(), "/script"));
        assertEq(
            harness.resolveOutputFile("", "Batches.json"), string.concat(vm.projectRoot(), "/script/Batches.json")
        );
    }

    function testUsesRequestScopedDirectory() public view {
        string memory outputDir = string.concat(vm.projectRoot(), "/test/MarketOps");

        assertEq(harness.resolveOutputDir(string.concat(outputDir, "/")), outputDir);
        assertEq(
            harness.resolveOutputFile(string.concat(outputDir, "/"), "Batches.json"),
            string.concat(outputDir, "/Batches.json")
        );
    }
}
