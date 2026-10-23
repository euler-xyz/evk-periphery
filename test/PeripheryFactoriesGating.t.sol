// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PeripheryFactories, isCapRiskStewardFactoryBoundTo} from "../script/02_PeripheryFactories.s.sol";
import {CapRiskStewardFactory} from "../src/GovernorFactory/CapRiskStewardFactory.sol";

contract LegacyCapRiskStewardFactory {
    function irmFactory() external pure returns (address) {
        return address(1);
    }
}

/// @dev Starts from the chain-999 state (most factories deployed, two left at zero) with a V2 governor factory and a
/// capRiskStewardFactory bound to it in place.
contract PeripheryFactoriesGatingTest is Test {
    PeripheryFactories deployer;
    address constant EVC = address(0xE7C);
    address governorFactoryV2;

    function setUp() public {
        // ScriptExtended resolves the deployer from DEPLOYER_KEY at construction
        vm.setEnv("DEPLOYER_KEY", "1");
        deployer = new PeripheryFactories();
        governorFactoryV2 = makeAddr("governorFactoryV2");
    }

    function _chain999State() internal returns (PeripheryFactories.PeripheryContracts memory s) {
        s.oracleRouterFactory = 0x1CefA54ebBCb6c9Aa7347196B03364aFe9A89f7e;
        s.kinkIRMFactory = 0xc1254039763498485a0BC11eb51437A312641bf0;
        s.kinkyIRMFactory = address(0); // missing
        s.fixedCyclicalBinaryIRMFactory = address(0); // missing
        s.adaptiveCurveIRMFactory = 0xF62bFaA502E4dC83260e34aCF2B4875FdBDc31c9;
        s.governorAccessControlEmergencyFactoryV2 = governorFactoryV2;
        s.capRiskStewardFactory = address(new CapRiskStewardFactory(governorFactoryV2, s.kinkIRMFactory));
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
        assertEq(
            after_.governorAccessControlEmergencyFactoryV2, before.governorAccessControlEmergencyFactoryV2, "governor"
        );
        assertEq(after_.capRiskStewardFactory, before.capRiskStewardFactory, "capRiskStewardFactory");
    }

    function test_freshDeploy_populatesEverything() public {
        PeripheryFactories.PeripheryContracts memory result = deployer.execute(EVC);

        assertTrue(result.oracleRouterFactory != address(0), "oracleRouterFactory");
        assertTrue(result.kinkIRMFactory != address(0), "kinkIRMFactory");
        assertTrue(result.kinkyIRMFactory != address(0), "kinkyIRMFactory");
        assertTrue(result.fixedCyclicalBinaryIRMFactory != address(0), "fixedCyclicalBinaryIRMFactory");
        assertTrue(result.adaptiveCurveIRMFactory != address(0), "adaptiveCurveIRMFactory");
        assertTrue(result.governorAccessControlEmergencyFactoryV2 != address(0), "governor");
        assertTrue(result.capRiskStewardFactory != address(0), "capRiskStewardFactory");
        assertTrue(
            isCapRiskStewardFactoryBoundTo(
                result.capRiskStewardFactory, result.governorAccessControlEmergencyFactoryV2
            ),
            "capRiskStewardFactory bound to the V2 governor factory"
        );
    }

    /// @dev capRiskStewardFactory must bind to the resolved (pre-existing) kink IRM factory, not a fresh one.
    function test_capRiskSteward_bindsToExistingDependencies() public {
        PeripheryFactories.PeripheryContracts memory before;
        before.kinkIRMFactory = 0xc1254039763498485a0BC11eb51437A312641bf0;
        before.governorAccessControlEmergencyFactoryV2 = governorFactoryV2;

        PeripheryFactories.PeripheryContracts memory after_ = deployer.execute(EVC, before);

        assertEq(after_.kinkIRMFactory, before.kinkIRMFactory, "kinkIRMFactory reused");
        assertEq(
            after_.governorAccessControlEmergencyFactoryV2, before.governorAccessControlEmergencyFactoryV2, "gov reused"
        );
        assertTrue(after_.capRiskStewardFactory != address(0), "capRiskStewardFactory deployed");
        assertEq(CapRiskStewardFactory(after_.capRiskStewardFactory).irmFactory(), before.kinkIRMFactory, "irm bound");
    }

    /// @dev A capRiskStewardFactory without the `governorAccessControlFactory()` getter is replaced, not reverted on.
    function test_capRiskSteward_redeployedWhenItHasNoGovernorFactoryGetter() public {
        PeripheryFactories.PeripheryContracts memory before = _chain999State();
        before.capRiskStewardFactory = address(new LegacyCapRiskStewardFactory());

        PeripheryFactories.PeripheryContracts memory after_ = deployer.execute(EVC, before);

        assertTrue(after_.capRiskStewardFactory != before.capRiskStewardFactory, "capRiskStewardFactory replaced");
        assertTrue(
            isCapRiskStewardFactoryBoundTo(after_.capRiskStewardFactory, governorFactoryV2),
            "capRiskStewardFactory bound to the V2 governor factory"
        );
    }

    /// @dev A capRiskStewardFactory accepting governors from another governor factory is replaced under the same key.
    function test_capRiskSteward_redeployedWhenBoundToAnotherGovernorFactory() public {
        PeripheryFactories.PeripheryContracts memory before = _chain999State();
        address v1GovernorFactory = makeAddr("v1GovernorFactory");
        before.capRiskStewardFactory = address(new CapRiskStewardFactory(v1GovernorFactory, before.kinkIRMFactory));
        before.governorAccessControlEmergencyFactoryV2 = address(0);

        PeripheryFactories.PeripheryContracts memory after_ = deployer.execute(EVC, before);

        assertTrue(after_.governorAccessControlEmergencyFactoryV2 != address(0), "V2 governor factory deployed");
        assertTrue(after_.capRiskStewardFactory != before.capRiskStewardFactory, "capRiskStewardFactory replaced");
        assertTrue(
            isCapRiskStewardFactoryBoundTo(
                after_.capRiskStewardFactory, after_.governorAccessControlEmergencyFactoryV2
            ),
            "capRiskStewardFactory bound to the V2 governor factory"
        );
    }
}
