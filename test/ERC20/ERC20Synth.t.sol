// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {Errors} from "evk/EVault/shared/Errors.sol";
import {ERC20Synth, EVCUtil} from "../../src/ERC20/deployed/ERC20Synth.sol";
import "forge-std/console2.sol";

contract ERC20SynthTest is EVaultTestBase {
    uint128 constant MAX_CAPACITY = type(uint128).max;

    ERC20Synth esynth;
    address user1;
    address user2;
    address defaultAdmin;
    address allocator;
    address minter;
    address revokeMinter;
    address ignored1;
    address ignored2;
    address ignored3;

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    function setUp() public virtual override {
        super.setUp();

        user1 = vm.addr(1001);
        user2 = vm.addr(1002);
        defaultAdmin = makeAddr("defaultAdmin");
        minter = makeAddr("minter");
        revokeMinter = makeAddr("revokeMinter");
        allocator = makeAddr("allocator");
        ignored1 = makeAddr("ignored1");
        ignored2 = makeAddr("ignored2");
        ignored3 = makeAddr("ignored3");

        esynth = ERC20Synth(address(new ERC20Synth(address(evc), defaultAdmin, "Test Synth", "TST", 18)));
        assetTST = TestERC20(address(esynth));

        eTST = createSynthEVault(address(assetTST));

        bytes32 role = esynth.MINTER_ROLE();
        vm.prank(defaultAdmin);
        esynth.grantRole(role, minter);

        role = esynth.REVOKE_MINTER_ROLE();
        vm.prank(defaultAdmin);
        esynth.grantRole(role, revokeMinter);

        role = esynth.ALLOCATOR_ROLE();
        vm.prank(defaultAdmin);
        esynth.grantRole(role, allocator);
    }

    function test_grantRevokeRenounceRole() public {
        bytes32 minterRole = esynth.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user1);
        esynth.grantRole(minterRole, user2);

        vm.prank(defaultAdmin);
        esynth.grantRole(minterRole, user2);
        assertTrue(esynth.hasRole(minterRole, user2));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user1);
        esynth.revokeRole(minterRole, user2);

        vm.prank(defaultAdmin);
        esynth.revokeRole(minterRole, user2);
        assertTrue(!esynth.hasRole(minterRole, user2));

        // no-op
        vm.prank(user2);
        esynth.renounceRole(minterRole, user2);

        vm.prank(defaultAdmin);
        esynth.grantRole(minterRole, user2);
        assertTrue(esynth.hasRole(minterRole, user2));
        vm.prank(user2);
        esynth.renounceRole(minterRole, user2);
        assertTrue(!esynth.hasRole(minterRole, user2));
    }

    function test_addIgnoredForTotalSupply_onlyAllocator() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), esynth.ALLOCATOR_ROLE()
            )
        );
        esynth.addIgnoredForTotalSupply(ignored1);
    }

    function test_addIgnored() public {
        vm.prank(allocator);
        bool success = esynth.addIgnoredForTotalSupply(ignored1);

        address[] memory ignored = esynth.getAllIgnoredForTotalSupply();
        assertEq(ignored.length, 2);
        assertEq(ignored[0], address(esynth));
        assertEq(ignored[1], ignored1);
        assertTrue(success);
    }

    function test_addIgnored_duplicate() public {
        vm.startPrank(allocator);
        esynth.addIgnoredForTotalSupply(ignored1);
        bool success = esynth.addIgnoredForTotalSupply(ignored1);
        vm.stopPrank();

        address[] memory ignored = esynth.getAllIgnoredForTotalSupply();
        assertEq(ignored.length, 2);
        assertEq(ignored[0], address(esynth));
        assertEq(ignored[1], ignored1);
        assertFalse(success);
    }

    function test_removeIgnoredForTotalSupply_onlyAllocator() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), esynth.ALLOCATOR_ROLE()
            )
        );
        esynth.removeIgnoredForTotalSupply(ignored1);
    }

    function test_removeIgnored() public {
        vm.startPrank(allocator);
        esynth.addIgnoredForTotalSupply(ignored1);
        bool success = esynth.removeIgnoredForTotalSupply(ignored1);
        vm.stopPrank();

        address[] memory ignored = esynth.getAllIgnoredForTotalSupply();
        assertEq(ignored[0], address(esynth));
        assertEq(ignored.length, 1);
        assertTrue(success);
    }

    function test_removeIgnored_notFound() public {
        vm.startPrank(allocator);
        bool success = esynth.removeIgnoredForTotalSupply(ignored1);
        vm.stopPrank();

        address[] memory ignored = esynth.getAllIgnoredForTotalSupply();
        assertEq(ignored[0], address(esynth));
        assertEq(ignored.length, 1);
        assertFalse(success);
    }

    function test_totalSupply_nothingIgnoredExceptSynth() public {
        vm.prank(defaultAdmin);
        esynth.setCapacity(defaultAdmin, 1000000e18);

        vm.startPrank(defaultAdmin);
        esynth.mint(address(esynth), 100);
        esynth.mint(ignored1, 200);
        esynth.mint(ignored2, 300);
        esynth.mint(ignored3, 400);
        vm.stopPrank();

        assertEq(esynth.totalSupply(), 900);
    }

    function test_TotalSupplyAddresses_ignored() public {
        vm.prank(defaultAdmin);
        esynth.setCapacity(defaultAdmin, 1000000e18);

        vm.startPrank(defaultAdmin);
        esynth.mint(address(esynth), 100);
        esynth.mint(ignored1, 200);
        esynth.mint(ignored2, 300);
        esynth.mint(ignored3, 400);
        vm.stopPrank();

        vm.startPrank(allocator);
        esynth.addIgnoredForTotalSupply(ignored1);
        esynth.addIgnoredForTotalSupply(ignored2);

        assertEq(esynth.totalSupply(), 400);
    }

    function testFuzz_mintShouldIncreaseTotalSupplyAndBalance(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_CAPACITY));
        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);

        vm.prank(minter);
        esynth.mint(user1, amount);
        assertEq(esynth.balanceOf(user1), balanceBefore + amount);
        assertEq(esynth.totalSupply(), totalSupplyBefore + amount);
    }

    function testFuzz_burnFromShouldDecreaseTotalSupplyAndBalance(uint128 initialAmount, uint128 burnAmount) public {
        initialAmount = uint128(bound(initialAmount, 1, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);
        vm.prank(minter);
        esynth.mint(user1, initialAmount);
        burnAmount = uint128(bound(burnAmount, 1, initialAmount));

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, user2, 0, burnAmount));
        vm.prank(user2);
        esynth.burnFrom(user1, burnAmount);

        vm.prank(user1);
        esynth.approve(user2, burnAmount);

        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();

        vm.prank(user2);
        esynth.burnFrom(user1, burnAmount);

        assertEq(esynth.balanceOf(user1), balanceBefore - burnAmount);
        assertEq(esynth.totalSupply(), totalSupplyBefore - burnAmount);
        assertEq(esynth.allowance(user1, user2), 0);
    }

    function testFuzz_burnShouldDecreaseTotalSupplyAndBalance(uint128 initialAmount, uint128 burnAmount) public {
        initialAmount = uint128(bound(initialAmount, 1, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);
        vm.prank(minter);
        esynth.mint(user1, initialAmount);
        burnAmount = uint128(bound(burnAmount, 1, initialAmount));

        uint256 balanceBefore = esynth.balanceOf(user1);
        uint256 totalSupplyBefore = esynth.totalSupply();

        vm.prank(user1);
        esynth.burn(burnAmount);

        assertEq(esynth.balanceOf(user1), balanceBefore - burnAmount);
        assertEq(esynth.totalSupply(), totalSupplyBefore - burnAmount);
    }

    function testFuzz_mintCapacityReached(uint128 capacity, uint128 amount) public {
        capacity = uint128(bound(capacity, 0, MAX_CAPACITY));
        amount = uint128(bound(amount, 0, MAX_CAPACITY));
        vm.assume(capacity < amount);
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, capacity);
        vm.expectRevert(ERC20Synth.CapacityReached.selector);
        vm.prank(minter);
        esynth.mint(user1, amount);
    }

    function testFuzz_maxCapacityMint(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);

        vm.prank(minter);
        esynth.mint(minter, amount);

        (uint128 capacity, uint128 minted) = esynth.minters(minter);

        // capacity is not reduced
        assertEq(capacity, MAX_CAPACITY);
        // minted is not increased
        assertEq(minted, 0);
        // burn is allowed with minted 0
        vm.prank(minter);
        esynth.burnFrom(minter, amount);
    }

    function testFuzz_maxCapacityIsNotDecreasedByMint(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);

        vm.prank(minter);
        esynth.mint(user1, amount);

        (uint128 capacity, uint128 minted) = esynth.minters(minter);
        assertEq(capacity, MAX_CAPACITY);
        assertEq(minted, 0); // with max capacity minted is not increased
    }

    // burn of amount more then minted shoud reset minterCache.minted to 0
    function testFuzz_burnMoreThanMinted(uint128 amount) public {
        amount = uint128(bound(amount, 0, MAX_CAPACITY / 2));
        // one minter mints
        vm.prank(defaultAdmin);
        esynth.setCapacity(user2, amount); // we set the cap to less then
        vm.prank(user2);
        esynth.mint(address(esynth), amount);

        // another minter mints
        vm.prank(defaultAdmin);
        esynth.setCapacity(user1, amount); // we set the cap to less then
        vm.prank(user1);
        esynth.mint(address(esynth), amount);

        // the owner of the synth can always burn from synth
        vm.prank(defaultAdmin);
        esynth.burnFrom(address(esynth), amount * 2);

        (, uint128 minted) = esynth.minters(address(this));
        assertEq(minted, 0);
    }

    function testFuzz_burnFromOwner(uint128 amount) public {
        amount = uint128(bound(amount, 1, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(user1, MAX_CAPACITY);
        vm.prank(user1);
        esynth.mint(user1, amount);

        // the owner of the synth can always burn from synth but cannot from other accounts without allowance
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(this), 0, amount));
        esynth.burnFrom(user1, amount);

        vm.prank(user1);
        esynth.approve(address(this), amount);
        esynth.burnFrom(user1, amount);

        assertEq(esynth.balanceOf(user1), 0);
    }

    function testFuzz_depositSimple(uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint112).max)); // amount needs to be less then MAX_SANE_AMOUNT
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);
        vm.prank(minter);
        esynth.mint(address(esynth), amount); // address(this) should be owner
        vm.prank(allocator);
        esynth.allocate(address(eTST), amount);
    }

    function testFuzz_depositTooLarge(uint128 amount) public {
        amount = uint128(bound(amount, uint256(type(uint112).max) + 1, MAX_CAPACITY));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);
        vm.prank(minter);
        esynth.mint(address(esynth), amount);
        vm.expectRevert(Errors.E_AmountTooLargeToEncode.selector);
        vm.prank(allocator);
        esynth.allocate(address(eTST), amount);
    }

    function testFuzz_withdrawSimple(uint128 amount) public {
        amount = uint128(bound(amount, 1, type(uint112).max));
        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, MAX_CAPACITY);
        vm.prank(minter);
        esynth.mint(address(esynth), amount);
        vm.startPrank(allocator);
        esynth.allocate(address(eTST), amount);
        esynth.deallocate(address(eTST), amount);
    }

    function test_GovernanceModifiers(address admin, uint8 id, address nonAdmin, uint128 amount) public {
        vm.assume(admin != address(0) && admin != address(evc));
        vm.assume(!evc.haveCommonOwner(admin, nonAdmin) && nonAdmin != address(evc));
        vm.assume(id != 0);

        vm.prank(admin);
        esynth = ERC20Synth(address(new ERC20Synth(address(evc), admin, "Test Synth", "TST", 18)));

        // succeeds if called directly by an admin
        vm.prank(admin);
        esynth.setCapacity(address(this), amount);

        // fails if called by a non-admin
        vm.prank(nonAdmin);
        vm.expectRevert();
        esynth.setCapacity(address(this), amount);

        // succeeds if called by an admin through the EVC
        vm.prank(admin);
        evc.call(address(esynth), admin, 0, abi.encodeCall(ERC20Synth.setCapacity, (address(this), amount)));

        // fails if called by non-admin through the EVC
        vm.prank(nonAdmin);
        vm.expectRevert();
        evc.call(address(esynth), nonAdmin, 0, abi.encodeCall(ERC20Synth.setCapacity, (address(this), amount)));

        // fails if called by a sub-account of admin through the EVC
        vm.prank(admin);
        vm.expectRevert();
        evc.call(
            address(esynth),
            address(uint160(admin) ^ id),
            0,
            abi.encodeCall(ERC20Synth.setCapacity, (address(this), amount))
        );

        // fails if called by the admin operator through the EVC
        vm.prank(admin);
        evc.setAccountOperator(admin, nonAdmin, true);
        vm.prank(nonAdmin);
        vm.expectRevert();
        evc.call(address(esynth), admin, 0, abi.encodeCall(ERC20Synth.setCapacity, (address(this), amount)));

        // other functions
        revertSubaccountHelper(
            address(esynth), admin, id, abi.encodeCall(ERC20Synth.grantRole, (bytes32(0), address(0)))
        );
        revertSubaccountHelper(
            address(esynth), admin, id, abi.encodeCall(ERC20Synth.revokeRole, (bytes32(0), address(0)))
        );
        revertSubaccountHelper(
            address(esynth), admin, id, abi.encodeCall(ERC20Synth.renounceRole, (bytes32(0), address(0)))
        );
        revertSubaccountHelper(address(esynth), admin, id, abi.encodeCall(ERC20Synth.mint, (address(0), 0)));
        revertSubaccountHelper(address(esynth), admin, id, abi.encodeCall(ERC20Synth.allocate, (address(0), 0)));
        revertSubaccountHelper(address(esynth), admin, id, abi.encodeCall(ERC20Synth.deallocate, (address(0), 0)));
        revertSubaccountHelper(
            address(esynth), admin, id, abi.encodeCall(ERC20Synth.addIgnoredForTotalSupply, (address(0)))
        );
        revertSubaccountHelper(
            address(esynth), admin, id, abi.encodeCall(ERC20Synth.removeIgnoredForTotalSupply, (address(0)))
        );
    }

    function test_Roles() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(user1);
        esynth.setCapacity(minter, 1e18);

        vm.prank(defaultAdmin);
        esynth.setCapacity(minter, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.ALLOCATOR_ROLE()
            )
        );
        vm.prank(user1);
        esynth.addIgnoredForTotalSupply(address(eTST));

        vm.prank(allocator);
        esynth.addIgnoredForTotalSupply(address(eTST));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.ALLOCATOR_ROLE()
            )
        );
        vm.prank(user1);
        esynth.removeIgnoredForTotalSupply(address(eTST));

        vm.prank(allocator);
        esynth.removeIgnoredForTotalSupply(address(eTST));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.MINTER_ROLE()
            )
        );
        vm.prank(user1);
        esynth.mint(address(esynth), 1e18);

        vm.prank(minter);
        esynth.mint(address(esynth), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.ALLOCATOR_ROLE()
            )
        );
        vm.prank(user1);
        esynth.allocate(address(eTST), 1e18);

        vm.prank(allocator);
        esynth.allocate(address(eTST), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.ALLOCATOR_ROLE()
            )
        );
        vm.prank(user1);
        esynth.deallocate(address(eTST), 1e18);

        vm.prank(allocator);
        esynth.deallocate(address(eTST), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, esynth.REVOKE_MINTER_ROLE()
            )
        );
        vm.prank(user1);
        esynth.revokeMinterRole(minter);

        vm.prank(revokeMinter);
        esynth.revokeMinterRole(minter);

        assertTrue(!esynth.hasRole(esynth.MINTER_ROLE(), minter));
    }

    function revertSubaccountHelper(address synth, address admin, uint8 id, bytes memory data) internal {
        vm.prank(admin);

        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(synth, address(uint160(admin) ^ id), 0, data);
    }
}
