// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PeripheryFactories} from "../script/02_PeripheryFactories.s.sol";

/// @dev Reproduces the chain-999 state: most factories deployed, two left at zero.
contract PeripheryFactoriesGatingTest is Test {
    PeripheryFactories deployer;
    address constant EVC = address(0xE7C);

    function setUp() public {
        // ScriptExtended resolves the deployer from DEPLOYER_KEY at construction
        vm.setEnv("DEPLOYER_KEY", "1");
        deployer = new PeripheryFactories();
    }

    function _chain999State() internal pure returns (PeripheryFactories.PeripheryContracts memory s) {
        s.oracleRouterFactory = 0x1CefA54ebBCb6c9Aa7347196B03364aFe9A89f7e;
        s.kinkIRMFactory = 0xc1254039763498485a0BC11eb51437A312641bf0;
        s.kinkyIRMFactory = address(0); // missing
        s.fixedCyclicalBinaryIRMFactory = address(0); // missing
        s.adaptiveCurveIRMFactory = 0xF62bFaA502E4dC83260e34aCF2B4875FdBDc31c9;
        s.governorAccessControlEmergencyFactory = 0xaD9cc6ECf49376de4Ea10494Cb519a848e5e74F3;
        s.capRiskStewardFactory = 0x459Fe76a4fc9406feBe3AcFdb42955197059b089;
    }

    function test_deploysOnlyMissing_preservesExisting() public {
        PeripheryFactories.PeripheryContracts memory before = _chain999State();
        PeripheryFactories.PeripheryContracts memory after_ = deployer.execute(EVC, before);

        // the two gaps are filled
        assertTrue(after_.kinkyIRMFactory != address(0), "kinkyIRMFactory must be deployed");
        assertTrue(after_.fixedCyclicalBinaryIRMFactory != address(0), "fixedCyclicalBinaryIRMFactory must be deployed");
        assertTrue(after_.kinkyIRMFactory.code.length > 0, "kinkyIRMFactory must have code");
        assertTrue(after_.fixedCyclicalBinaryIRMFactory.code.length > 0, "fixedCyclical must have code");

        // every already-deployed address is untouched
        assertEq(after_.oracleRouterFactory, before.oracleRouterFactory, "oracleRouterFactory");
        assertEq(after_.kinkIRMFactory, before.kinkIRMFactory, "kinkIRMFactory");
        assertEq(after_.adaptiveCurveIRMFactory, before.adaptiveCurveIRMFactory, "adaptiveCurveIRMFactory");
        assertEq(after_.governorAccessControlEmergencyFactory, before.governorAccessControlEmergencyFactory, "governor");
        assertEq(after_.capRiskStewardFactory, before.capRiskStewardFactory, "capRiskStewardFactory");
    }

    function test_freshDeploy_populatesEverything() public {
        PeripheryFactories.PeripheryContracts memory result = deployer.execute(EVC);

        assertTrue(result.oracleRouterFactory != address(0), "oracleRouterFactory");
        assertTrue(result.kinkIRMFactory != address(0), "kinkIRMFactory");
        assertTrue(result.kinkyIRMFactory != address(0), "kinkyIRMFactory");
        assertTrue(result.fixedCyclicalBinaryIRMFactory != address(0), "fixedCyclicalBinaryIRMFactory");
        assertTrue(result.adaptiveCurveIRMFactory != address(0), "adaptiveCurveIRMFactory");
        assertTrue(result.governorAccessControlEmergencyFactory != address(0), "governor");
        assertTrue(result.capRiskStewardFactory != address(0), "capRiskStewardFactory");
    }

    /// @dev capRiskStewardFactory must bind to the resolved (pre-existing) kink IRM factory, not a fresh one.
    function test_capRiskSteward_bindsToExistingDependencies() public {
        PeripheryFactories.PeripheryContracts memory before;
        before.kinkIRMFactory = 0xc1254039763498485a0BC11eb51437A312641bf0;
        before.governorAccessControlEmergencyFactory = 0xaD9cc6ECf49376de4Ea10494Cb519a848e5e74F3;

        PeripheryFactories.PeripheryContracts memory after_ = deployer.execute(EVC, before);

        assertEq(after_.kinkIRMFactory, before.kinkIRMFactory, "kinkIRMFactory reused");
        assertEq(
            after_.governorAccessControlEmergencyFactory, before.governorAccessControlEmergencyFactory, "gov reused"
        );
        assertTrue(after_.capRiskStewardFactory != address(0), "capRiskStewardFactory deployed");
    }
}
