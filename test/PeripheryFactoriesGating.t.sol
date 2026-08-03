// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PeripheryFactories} from "../script/02_PeripheryFactories.s.sol";

/// @dev Reproduces the chain-999 state: most factories deployed, two left at zero.
contract PeripheryFactoriesGatingTest is Test {
    PeripheryFactories deployer;
    address constant EVC = address(0xE7C);

    function setUp() public {
        // ScriptExtended resolves the deployer from DEPLOYER_KEY at construction; SnapshotRegistry rejects a zero owner
        vm.setEnv("DEPLOYER_KEY", "1");
        deployer = new PeripheryFactories();
    }

    function _chain999State() internal pure returns (PeripheryFactories.PeripheryContracts memory s) {
        s.oracleRouterFactory = 0x1CefA54ebBCb6c9Aa7347196B03364aFe9A89f7e;
        s.oracleAdapterRegistry = 0x66390e34511DA5DbFeD572Cc5B1337Fe57AD02E7;
        s.externalVaultRegistry = 0xe09af00Dad8f1d2F056f08Ea1059aa6cA6397FEE;
        s.kinkIRMFactory = 0xc1254039763498485a0BC11eb51437A312641bf0;
        s.kinkyIRMFactory = address(0); // missing
        s.fixedCyclicalBinaryIRMFactory = address(0); // missing
        s.adaptiveCurveIRMFactory = 0xF62bFaA502E4dC83260e34aCF2B4875FdBDc31c9;
        s.irmRegistry = 0x52930DC1b386348E9be3C9260659Dd910384A49d;
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

        // every already-deployed address is untouched — critically the stateful registries
        assertEq(after_.oracleRouterFactory, before.oracleRouterFactory, "oracleRouterFactory");
        assertEq(after_.oracleAdapterRegistry, before.oracleAdapterRegistry, "oracleAdapterRegistry");
        assertEq(after_.externalVaultRegistry, before.externalVaultRegistry, "externalVaultRegistry");
        assertEq(after_.kinkIRMFactory, before.kinkIRMFactory, "kinkIRMFactory");
        assertEq(after_.adaptiveCurveIRMFactory, before.adaptiveCurveIRMFactory, "adaptiveCurveIRMFactory");
        assertEq(after_.irmRegistry, before.irmRegistry, "irmRegistry");
        assertEq(after_.governorAccessControlEmergencyFactory, before.governorAccessControlEmergencyFactory, "governor");
        assertEq(after_.capRiskStewardFactory, before.capRiskStewardFactory, "capRiskStewardFactory");
    }

    function test_freshDeploy_populatesEverything() public {
        PeripheryFactories.PeripheryContracts memory result = deployer.execute(EVC);

        assertTrue(result.oracleRouterFactory != address(0), "oracleRouterFactory");
        assertTrue(result.oracleAdapterRegistry != address(0), "oracleAdapterRegistry");
        assertTrue(result.externalVaultRegistry != address(0), "externalVaultRegistry");
        assertTrue(result.kinkIRMFactory != address(0), "kinkIRMFactory");
        assertTrue(result.kinkyIRMFactory != address(0), "kinkyIRMFactory");
        assertTrue(result.fixedCyclicalBinaryIRMFactory != address(0), "fixedCyclicalBinaryIRMFactory");
        assertTrue(result.adaptiveCurveIRMFactory != address(0), "adaptiveCurveIRMFactory");
        assertTrue(result.irmRegistry != address(0), "irmRegistry");
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
