// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {AccountLens} from "../../src/Lens/AccountLens.sol";
import {AccountMultipleVaultsInfo} from "../../src/Lens/LensTypes.sol";

/// @dev EVC.enableCollateral accepts any address, so a collateral whose return data cannot be decoded must not be able
/// to revert the whole account query.
contract AccountLensHostileCollateralTest is Test {
    AccountLens lens;

    address constant EVC = address(0xE7C);
    address constant GOOD = address(0x600D);
    address constant ASSET = address(0xCAFE);
    address constant HOSTILE = address(0xBAD);
    address constant ACCOUNT = address(0xA11CE);

    function setUp() public {
        lens = new AccountLens();
        vm.etch(EVC, hex"00");
        vm.etch(GOOD, hex"00");
        vm.etch(ASSET, hex"00");
        vm.etch(HOSTILE, hex"00");

        vm.mockCall(EVC, abi.encodeCall(IEVC.getAddressPrefix, (ACCOUNT)), abi.encode(bytes19(0)));
        vm.mockCall(EVC, abi.encodeCall(IEVC.getAccountOwner, (ACCOUNT)), abi.encode(ACCOUNT));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isLockdownMode, (bytes19(0))), abi.encode(false));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isPermitDisabledMode, (bytes19(0))), abi.encode(false));
        vm.mockCall(EVC, abi.encodeCall(IEVC.getLastAccountStatusCheckTimestamp, (ACCOUNT)), abi.encode(uint256(0)));
        vm.mockCall(EVC, abi.encodeCall(IEVC.getControllers, (ACCOUNT)), abi.encode(new address[](0)));

        address[] memory collaterals = new address[](2);
        collaterals[0] = GOOD;
        collaterals[1] = HOSTILE;
        vm.mockCall(EVC, abi.encodeCall(IEVC.getCollaterals, (ACCOUNT)), abi.encode(collaterals));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isControllerEnabled, (ACCOUNT, GOOD)), abi.encode(false));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isControllerEnabled, (ACCOUNT, HOSTILE)), abi.encode(false));

        // a well-behaved vault
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).asset, ()), abi.encode(ASSET));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).balanceOf, (ACCOUNT)), abi.encode(uint256(1234)));
        vm.mockCall(ASSET, abi.encodeCall(IEVault(ASSET).balanceOf, (ACCOUNT)), abi.encode(uint256(5678)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).convertToAssets, (uint256(1234))), abi.encode(uint256(9999)));
        vm.mockCall(ASSET, abi.encodeCall(IEVault(ASSET).allowance, (ACCOUNT, GOOD)), abi.encode(uint256(0)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).permit2Address, ()), abi.encode(address(0)));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).balanceForwarderEnabled, (ACCOUNT)), abi.encode(false));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).EVC, ()), abi.encode(EVC));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isCollateralEnabled, (ACCOUNT, GOOD)), abi.encode(true));
        vm.mockCall(GOOD, abi.encodeCall(IEVault(GOOD).balanceTrackerAddress, ()), abi.encode(address(0)));

        // hostile: a colliding selector returns a wide integer where an address is decoded
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).asset, ()), abi.encode(ASSET));
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).balanceOf, (ACCOUNT)), abi.encode(uint256(1)));
        vm.mockCall(ASSET, abi.encodeCall(IEVault(ASSET).balanceOf, (ACCOUNT)), abi.encode(uint256(5678)));
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).convertToAssets, (uint256(1))), abi.encode(uint256(1)));
        vm.mockCall(ASSET, abi.encodeCall(IEVault(ASSET).allowance, (ACCOUNT, HOSTILE)), abi.encode(uint256(0)));
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).permit2Address, ()), abi.encode(type(uint256).max));
        vm.mockCall(HOSTILE, abi.encodeCall(IEVault(HOSTILE).balanceTrackerAddress, ()), abi.encode(address(0)));
    }

    /// @dev without the isolation this whole call reverts
    function test_hostileCollateral_doesNotRevertAccountQuery() public {
        AccountMultipleVaultsInfo memory info = lens.getAccountEnabledVaultsInfo(EVC, ACCOUNT);

        assertEq(info.vaultAccountInfo.length, 2, "both collaterals present");

        assertEq(info.vaultAccountInfo[0].vault, GOOD, "good vault first");
        assertFalse(info.vaultAccountInfo[0].queryFailure, "good vault reports no failure");
        assertEq(info.vaultAccountInfo[0].shares, 1234, "good vault data intact");
        assertEq(info.vaultAccountInfo[0].assets, 9999, "good vault data intact");

        assertEq(info.vaultAccountInfo[1].vault, HOSTILE, "hostile vault second");
        assertTrue(info.vaultAccountInfo[1].queryFailure, "hostile vault flagged");
        assertTrue(info.vaultAccountInfo[1].liquidityInfo.queryFailure, "nested flag set too");
        assertEq(info.vaultAccountInfo[1].account, ACCOUNT, "stub still identifies the account");
    }

    /// @dev the direct single-vault query is unchanged and still reverts, so callers see the real error
    function test_directQuery_stillPropagates() public {
        vm.expectRevert();
        lens.getVaultAccountInfo(ACCOUNT, HOSTILE);
    }

    /// @dev the isolating wrapper is callable on its own
    function test_tryGetVaultAccountInfo_flagsInsteadOfReverting() public {
        assertTrue(lens.tryGetVaultAccountInfo(ACCOUNT, HOSTILE).queryFailure, "flagged");
        assertFalse(lens.tryGetVaultAccountInfo(ACCOUNT, GOOD).queryFailure, "good vault unaffected");
    }

    /// @dev a collateral that is also a controller must not be written twice
    function test_collateralThatIsAlsoController_notDuplicated() public {
        address[] memory controllers = new address[](1);
        controllers[0] = GOOD;
        vm.mockCall(EVC, abi.encodeCall(IEVC.getControllers, (ACCOUNT)), abi.encode(controllers));
        vm.mockCall(EVC, abi.encodeCall(IEVC.isControllerEnabled, (ACCOUNT, GOOD)), abi.encode(true));

        AccountMultipleVaultsInfo memory info = lens.getAccountEnabledVaultsInfo(EVC, ACCOUNT);

        assertEq(info.vaultAccountInfo.length, 2, "one controller + one non-controller collateral");
        assertEq(info.vaultAccountInfo[0].vault, GOOD, "controller slot");
        assertEq(info.vaultAccountInfo[1].vault, HOSTILE, "collateral slot");
    }
}
