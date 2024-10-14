// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {GovernorAccessControl} from "../../src/Governor/GovernorAccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";

contract MockTarget {
    function foo() external pure returns (uint256) {
        return 1;
    }

    function bar() external pure returns (bytes memory) {
        return abi.encode(2);
    }
}

contract GovernorAccessControlTest is Test {
    MockTarget public mockTarget;
    EthereumVaultConnector public evc;
    GovernorAccessControl public governorAccessControl;
    address public admin;
    address public user1;
    address public user1SubAccount;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user1SubAccount = address(uint160(user1) ^ 100);
        mockTarget = new MockTarget();
        evc = new EthereumVaultConnector();
        governorAccessControl = new GovernorAccessControl(address(evc), admin);
    }

    function test_allowSelector() public {
        bytes memory data = abi.encodeCall(MockTarget.foo, ());
        bytes memory anyData = abi.encodeCall(MockTarget.bar, ());
        bytes4 selector = bytes4(data);

        vm.startPrank(admin);
        governorAccessControl.grantRole(selector, user1);
        assertTrue(governorAccessControl.hasRole(selector, user1));
        governorAccessControl.grantRole(selector, user1SubAccount);
        assertTrue(governorAccessControl.hasRole(selector, user1SubAccount));
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GovernorAccessControl.MsgDataInvalid.selector));
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data));

        vm.prank(user1);
        bytes memory result =
            evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data, mockTarget));
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(anyData, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(data, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(anyData, mockTarget));

        bool success;
        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(data);
        assertFalse(success);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(data, mockTarget));
        assertTrue(success);
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(anyData, mockTarget));
        assertFalse(success);
    }

    function test_allowAllSelectors() public {
        bytes memory data = abi.encodeCall(MockTarget.foo, ());
        bytes memory anyData = abi.encodeCall(MockTarget.bar, ());
        bytes32 wildcard = governorAccessControl.WILD_CARD();

        vm.startPrank(admin);
        governorAccessControl.grantRole(wildcard, user1);
        assertTrue(governorAccessControl.hasRole(wildcard, user1));
        governorAccessControl.grantRole(wildcard, user1SubAccount);
        assertTrue(governorAccessControl.hasRole(wildcard, user1SubAccount));
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GovernorAccessControl.MsgDataInvalid.selector));
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data));

        vm.prank(user1);
        bytes memory result =
            evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data, mockTarget));
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        result = evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(anyData, mockTarget));
        assertEq(keccak256(abi.decode(result, (bytes))), keccak256(abi.encode(2)));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(data, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(anyData, mockTarget));

        bool success;
        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(data);
        assertFalse(success);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(data, mockTarget));
        assertTrue(success);
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(anyData, mockTarget));
        assertTrue(success);
        assertEq(keccak256(abi.decode(result, (bytes))), keccak256(abi.encode(2)));
    }

    function test_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        governorAccessControl.grantRole(0, user1);
    }

    function test_revert_initializeTwice() public {
        vm.expectRevert();
        governorAccessControl.initialize(admin);
    }
}
