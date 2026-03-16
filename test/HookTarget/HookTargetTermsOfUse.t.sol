// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase, IERC20} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {HookTargetTermsOfUse} from "../../src/HookTarget/HookTargetTermsOfUse.sol";
import {TermsOfUseSigner} from "../../src/TermsOfUseSigner/TermsOfUseSigner.sol";
import {MockController} from "../Vault/lib/MockController.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import "evk/EVault/shared/Constants.sol";
import "forge-std/Vm.sol";

contract HookTargetTermsOfUseTest is EVaultTestBase {
    HookTargetTermsOfUse public hookTarget;
    TermsOfUseSigner public termsOfUseSigner;

    address public hookOwner;
    address public user1;
    address public user1SubAccount;
    address public user2;

    string constant TOS_MESSAGE = "I agree to the Terms of Use";
    bytes32 tosHash;

    function setUp() public override {
        super.setUp();

        hookOwner = makeAddr("hookOwner");
        user1 = makeAddr("user1");
        user1SubAccount = address(uint160(user1) ^ 1);
        user2 = makeAddr("user2");

        tosHash = keccak256(abi.encodePacked(TOS_MESSAGE));

        termsOfUseSigner = new TermsOfUseSigner(address(evc));
        hookTarget = new HookTargetTermsOfUse(
            address(evc), hookOwner, address(factory), address(termsOfUseSigner), tosHash
        );

        eTST.setHookConfig(address(hookTarget), OP_DEPOSIT);

        assetTST.mint(user1, 100e18);
        assetTST.mint(user2, 100e18);

        vm.prank(user1);
        assetTST.approve(address(eTST), type(uint256).max);

        vm.prank(user2);
        assetTST.approve(address(eTST), type(uint256).max);
    }

    // -- helpers --

    function _signTOS(address user) internal {
        vm.prank(user);
        evc.call(
            address(termsOfUseSigner),
            user,
            0,
            abi.encodeCall(TermsOfUseSigner.signTermsOfUse, (TOS_MESSAGE, tosHash))
        );
    }

    function _registerInEVC(address user) internal {
        vm.prank(user);
        evc.call(address(0), user, 0, "");
    }

    // -- constructor --

    function test_constructor() public view {
        assertEq(hookTarget.EVC(), address(evc));
        assertEq(hookTarget.termsOfUseContract(), address(termsOfUseSigner));
        assertEq(hookTarget.termsOfUseHash(), tosHash);
        assertEq(hookTarget.owner(), hookOwner);
    }

    function test_isHookTarget() public {
        vm.prank(address(eTST));
        assertEq(hookTarget.isHookTarget(), hookTarget.isHookTarget.selector);

        vm.prank(user1);
        assertEq(hookTarget.isHookTarget(), bytes4(0));
    }

    // -- owner access control --

    function test_setTermsOfUseHash_onlyOwner() public {
        bytes32 newHash = keccak256("new terms");

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        hookTarget.setTermsOfUseHash(newHash);
    }

    function test_addBypass_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        hookTarget.addBypass(user2);
    }

    function test_removeBypass_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        hookTarget.removeBypass(user2);
    }

    // -- setTermsOfUseHash --

    function test_setTermsOfUseHash() public {
        bytes32 newHash = keccak256("new terms");

        vm.prank(hookOwner);
        vm.expectEmit();
        emit HookTargetTermsOfUse.SetTermsOfUseHash(newHash);
        hookTarget.setTermsOfUseHash(newHash);

        assertEq(hookTarget.termsOfUseHash(), newHash);
    }

    function test_setTermsOfUseHash_invalidatesSignatures() public {
        _signTOS(user1);

        // user1 can deposit after signing
        vm.prank(user1);
        eTST.deposit(1e18, user1);

        // owner changes the hash
        bytes32 newHash = keccak256("new terms v2");
        vm.prank(hookOwner);
        hookTarget.setTermsOfUseHash(newHash);

        // user1 can no longer deposit
        vm.prank(user1);
        vm.expectRevert(HookTargetTermsOfUse.TermsOfUseNotSigned.selector);
        eTST.deposit(1e18, user1);
    }

    // -- TOS enforcement through vault deposit --

    function test_deposit_reverts_whenNotSigned() public {
        vm.prank(user1);
        vm.expectRevert(HookTargetTermsOfUse.TermsOfUseNotSigned.selector);
        eTST.deposit(1e18, user1);
    }

    function test_deposit_succeeds_whenSigned() public {
        _signTOS(user1);

        vm.prank(user1);
        eTST.deposit(1e18, user1);

        assertEq(eTST.balanceOf(user1), 1e18);
    }

    function test_deposit_succeeds_whenBypassed() public {
        // register user2 in EVC (so getAccountOwner returns user2)
        _registerInEVC(user2);

        // bypass user2 without requiring TOS
        vm.prank(hookOwner);
        hookTarget.addBypass(user2);

        vm.prank(user2);
        eTST.deposit(1e18, user2);

        assertEq(eTST.balanceOf(user2), 1e18);
    }

    function test_deposit_reverts_afterBypassRemoved() public {
        _registerInEVC(user2);

        vm.prank(hookOwner);
        hookTarget.addBypass(user2);

        // can deposit while bypassed
        vm.prank(user2);
        eTST.deposit(1e18, user2);

        // remove bypass
        vm.prank(hookOwner);
        hookTarget.removeBypass(user2);

        // can no longer deposit
        vm.prank(user2);
        vm.expectRevert(HookTargetTermsOfUse.TermsOfUseNotSigned.selector);
        eTST.deposit(1e18, user2);
    }

    // -- sub-account uses owner's TOS signature --

    function test_subAccount_usesOwnerSignature() public {
        // user1 signs TOS (registers as owner in EVC)
        _signTOS(user1);

        // fund the sub-account
        assetTST.mint(user1SubAccount, 100e18);
        vm.prank(user1SubAccount);
        assetTST.approve(address(eTST), type(uint256).max);

        // sub-account deposits through EVC on its own behalf
        // user1 (owner) calls on behalf of user1SubAccount
        vm.prank(user1);
        evc.call(address(eTST), user1SubAccount, 0, abi.encodeCall(eTST.deposit, (1e18, user1SubAccount)));

        assertEq(eTST.balanceOf(user1SubAccount), 1e18);
    }

    function test_deposit_succeeds_whenBypassed_throughEvc() public {
        // bypass user2
        vm.prank(hookOwner);
        hookTarget.addBypass(user2);

        // deposit through EVC (registers user2 in EVC and deposits in one call)
        vm.prank(user2);
        evc.call(address(eTST), user2, 0, abi.encodeCall(eTST.deposit, (1e18, user2)));

        assertEq(eTST.balanceOf(user2), 1e18);
    }

    function test_deposit_succeeds_whenSigned_notRegisteredInEVC() public {
        // user signs TOS directly (not through EVC), so no owner is registered in EVC
        vm.prank(user1);
        termsOfUseSigner.signTermsOfUse(TOS_MESSAGE, tosHash);

        // getAccountOwner(user1) returns address(0), fallback uses user1 directly
        assertEq(evc.getAccountOwner(user1), address(0));

        vm.prank(user1);
        eTST.deposit(1e18, user1);

        assertEq(eTST.balanceOf(user1), 1e18);
    }

    function test_deposit_succeeds_whenBypassed_notRegisteredInEVC() public {
        // bypass user2 without EVC registration
        vm.prank(hookOwner);
        hookTarget.addBypass(user2);

        // getAccountOwner(user2) returns address(0), fallback uses user2 directly
        assertEq(evc.getAccountOwner(user2), address(0));

        vm.prank(user2);
        eTST.deposit(1e18, user2);

        assertEq(eTST.balanceOf(user2), 1e18);
    }

    // -- checkVaultStatus bypass --

    function test_checkVaultStatusHook_bypassed_whenNotSigned() public {
        eTST.setHookConfig(address(hookTarget), OP_VAULT_STATUS_CHECK);

        // touch schedules a vault status check; OP_VAULT_STATUS_CHECK hook should bypass TOS checks
        vm.prank(user1);
        eTST.touch();
    }

    // -- owner functions through EVC --

    function test_setTermsOfUseHash_throughEVC() public {
        bytes32 newHash = keccak256("new terms");

        vm.prank(hookOwner);
        evc.call(
            address(hookTarget), hookOwner, 0, abi.encodeCall(HookTargetTermsOfUse.setTermsOfUseHash, (newHash))
        );

        assertEq(hookTarget.termsOfUseHash(), newHash);
    }
}
