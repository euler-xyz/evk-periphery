// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {GovernedPerspective} from "../../src/Perspectives/deployed/GovernedPerspective.sol";

contract GovernedPerspectiveTest is Test {
    function test_GovernedPerspective(address owner, address nonOwner, uint8 size, uint8 removeIndex, uint256 seed)
        public
    {
        vm.assume(owner != address(0) && owner != address(1) && nonOwner != address(1) && owner != nonOwner);
        vm.assume(size != 0);
        removeIndex = uint8(bound(removeIndex, 0, size - 1));

        address[] memory whitelist = new address[](size);
        address removeAddress;

        for (uint256 i = 0; i < size; i++) {
            whitelist[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));

            if (i == removeIndex) {
                removeAddress = whitelist[i];
            }
        }

        GovernedPerspective perspective = new GovernedPerspective(address(1), owner);

        assertEq(perspective.name(), "Governed Perspective");

        for (uint256 i = 0; i < size; i++) {
            vm.prank(nonOwner);
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
            perspective.perspectiveVerify(whitelist[i], true);
        }

        for (uint256 i = 0; i < size; i++) {
            vm.prank(owner);
            perspective.perspectiveVerify(whitelist[i], true);
        }

        for (uint256 i = 0; i < size; i++) {
            assertTrue(perspective.isVerified(whitelist[i]));
        }
        address[] memory verified = perspective.verifiedArray();
        assertEq(verified.length, size);
        for (uint256 i = 0; i < size; i++) {
            assertEq(verified[i], whitelist[i]);
        }
        assertEq(perspective.verifiedLength(), size);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        perspective.perspectiveUnverify(removeAddress);

        vm.prank(owner);
        perspective.perspectiveUnverify(removeAddress);
        assertFalse(perspective.isVerified(removeAddress));

        verified = perspective.verifiedArray();
        assertEq(verified.length, size - 1);
        bool found;
        for (uint256 i = 0; i < size - 1; i++) {
            if (verified[i] == removeAddress) found = true;
        }
        assertFalse(found);
        assertEq(perspective.verifiedLength(), size - 1);
    }

    function test_GovernedPerspectiveRenounceTransferOwnership() public {
        address OWNER = makeAddr("OWNER");
        address OWNER2 = makeAddr("OWNER2");
        address OWNER3 = makeAddr("OWNER3");
        GovernedPerspective perspective = new GovernedPerspective(address(1), OWNER);

        assertEq(perspective.owner(), OWNER);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        perspective.renounceOwnership();

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        perspective.transferOwnership(OWNER2);

        vm.prank(OWNER);
        perspective.transferOwnership(OWNER2);
        assertEq(perspective.owner(), OWNER2);

        vm.prank(OWNER2);
        perspective.transferOwnership(OWNER3);
        assertEq(perspective.owner(), OWNER3);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        perspective.renounceOwnership();

        vm.prank(OWNER3);
        perspective.renounceOwnership();
        assertEq(perspective.owner(), address(0));
    }
}
