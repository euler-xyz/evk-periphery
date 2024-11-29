// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Vm, Test} from "forge-std/Test.sol";
import {ERC20BurnableMintable} from "../../src/ERC20/deployed/ERC20BurnableMintable.sol";

contract ERC20BurnableMintableTest is Test {
    address admin = makeAddr("admin");
    ERC20BurnableMintable erc20;

    function setUp() public {
        erc20 = new ERC20BurnableMintable(admin, "ERC20", "ERC20", 5);
    }

    function test_constructor() external view {
        assertEq(erc20.hasRole(erc20.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(erc20.name(), "ERC20");
        assertEq(erc20.symbol(), "ERC20");
        assertEq(erc20.decimals(), 5);
        assertEq(erc20.balanceOf(admin), 0);
        assertEq(erc20.totalSupply(), 0);
    }

    function test_mint(address account, uint64 amount) external {
        vm.assume(account != address(0) && account != admin);
        vm.assume(amount > 0);

        bytes32 minterRole = erc20.MINTER_ROLE();
        bytes32 revokeMinterRole = erc20.REVOKE_MINTER_ROLE();

        // reverts if caller is not minter
        vm.expectRevert();
        erc20.mint(account, amount);

        vm.prank(admin);
        vm.expectRevert();
        erc20.mint(account, amount);

        vm.prank(account);
        vm.expectRevert();
        erc20.mint(account, amount);

        // reverts if not admin grants minter role
        vm.prank(account);
        vm.expectRevert();
        erc20.grantRole(minterRole, account);

        // succeeds if admin grants minter role
        vm.prank(admin);
        erc20.grantRole(minterRole, account);

        // succeeds if minter mints
        vm.prank(account);
        erc20.mint(account, amount);
        assertEq(erc20.balanceOf(account), amount);
        assertEq(erc20.totalSupply(), amount);

        // reverts if not revoke minter tries to revoke minter role
        vm.prank(account);
        vm.expectRevert();
        erc20.revokeMinterRole(account);

        vm.prank(admin);
        vm.expectRevert();
        erc20.revokeMinterRole(account);

        // reverts if not admin grants revoke minter role
        vm.prank(account);
        vm.expectRevert();
        erc20.grantRole(revokeMinterRole, account);

        // succeeds if admin grants revoke minter role
        vm.prank(admin);
        erc20.grantRole(revokeMinterRole, account);

        // succeeds if minter mints more
        vm.prank(account);
        erc20.mint(account, amount);
        assertEq(erc20.balanceOf(account), 2 * uint256(amount));
        assertEq(erc20.totalSupply(), 2 * uint256(amount));

        // succeeds if revoke minter revokes minter role
        vm.prank(account);
        erc20.revokeMinterRole(account);

        // reverts if old minter tries to mint more
        vm.prank(account);
        vm.expectRevert();
        erc20.mint(account, amount);
    }
}
