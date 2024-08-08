// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {GovernableWhitelistPerspective} from "../../src/Perspectives/deployed/GovernableWhitelistPerspective.sol";

contract GovernableWhitelistPerspectiveTest is Test {
    function test_GovernableWhitelistPerspective(address owner, address nonOwner, uint8 size, uint256 seed) public {
        vm.assume(owner != address(0) && owner != nonOwner);

        address[] memory whitelist = new address[](size);

        for (uint256 i = 0; i < size; i++) {
            whitelist[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
        }

        GovernableWhitelistPerspective perspective = new GovernableWhitelistPerspective(owner);

        assertEq(perspective.name(), "Governable Whitelist Perspective");

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
    }
}
