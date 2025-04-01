// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {HookTargetStakeDelegator} from "../../src/HookTarget/HookTargetStakeDelegator.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {console} from "forge-std/console.sol";

contract HookTargetStakeDelegatorTest is EVaultTestBase {
    HookTargetStakeDelegator public hookTargetStakeDelegator;
    address public user;
    uint256 public forkId;

    address public rewardVaultFactory = 0x94Ad6Ac84f6C6FbA8b8CCbD71d9f4f101def52a8;

    function setUp() public override {
        string memory rpc = vm.envString("BERA_RPC_URL");
        uint256 blockNumber = 3087244;
        forkId = vm.createSelectFork(rpc, blockNumber);

        super.setUp();
        user = makeAddr("user");
        hookTargetStakeDelegator = new HookTargetStakeDelegator(address(eTST), address(rewardVaultFactory));
    }

    function test_HookTargetStakeDelegator_setup() public {
        assertEq(address(hookTargetStakeDelegator.evc()), address(evc));
        console.log("hookTargetStakeDelegator.rewardVault()", address(hookTargetStakeDelegator.rewardVault()));
    }   

    // function test_allowSelector() public {
    //     bytes memory data = abi.encodeWithSignature("foo()");
    //     bytes memory anyData = abi.encodeWithSignature("bar()");
    //     bytes4 selector = bytes4(data);

    //     vm.startPrank(admin);
    //     hookTargetAccessControl.grantRole(selector, user1);
    //     assertTrue(hookTargetAccessControl.hasRole(selector, user1));
    //     hookTargetAccessControl.grantRole(selector, user1SubAccount);
    //     assertTrue(hookTargetAccessControl.hasRole(selector, user1SubAccount));
    //     vm.stopPrank();

    //     vm.prank(address(eTST));
    //     (bool success,) = address(hookTargetAccessControl).call(abi.encodePacked(data, user1));
    //     assertTrue(success);

    //     vm.prank(address(eTST));
    //     (success,) = address(hookTargetAccessControl).call(abi.encodePacked(anyData, user1));
    //     assertFalse(success);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1), 0, data);

    //     vm.prank(user1);
    //     vm.expectRevert();
    //     evc.call(address(hookTargetAccessControl), address(user1), 0, anyData);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, data);

    //     vm.prank(user1);
    //     vm.expectRevert();
    //     evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, anyData);

    //     vm.prank(user1);
    //     (success,) = address(hookTargetAccessControl).call(data);
    //     assertTrue(success);

    //     vm.prank(user1);
    //     (success,) = address(hookTargetAccessControl).call(anyData);
    //     assertFalse(success);
    // }

    // function test_allowAllSelectors() public {
    //     bytes memory data = abi.encodeWithSignature("foo()");
    //     bytes memory anyData = abi.encodeWithSignature("bar()");
    //     bytes32 wildcard = hookTargetAccessControl.WILD_CARD();

    //     vm.startPrank(admin);
    //     hookTargetAccessControl.grantRole(wildcard, user1);
    //     assertTrue(hookTargetAccessControl.hasRole(wildcard, user1));
    //     hookTargetAccessControl.grantRole(wildcard, user1SubAccount);
    //     assertTrue(hookTargetAccessControl.hasRole(wildcard, user1SubAccount));
    //     vm.stopPrank();

    //     vm.prank(address(eTST));
    //     (bool success,) = address(hookTargetAccessControl).call(abi.encodePacked(data, user1));
    //     assertTrue(success);

    //     vm.prank(address(eTST));
    //     (success,) = address(hookTargetAccessControl).call(abi.encodePacked(anyData, user1));
    //     assertTrue(success);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1), 0, data);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1), 0, anyData);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, data);

    //     vm.prank(user1);
    //     evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, anyData);

    //     vm.prank(user1);
    //     (success,) = address(hookTargetAccessControl).call(data);
    //     assertTrue(success);

    //     vm.prank(user1);
    //     (success,) = address(hookTargetAccessControl).call(anyData);
    //     assertTrue(success);
    // }

    // function test_revert_notAdmin() public {
    //     vm.startPrank(user1);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
    //     );
    //     hookTargetAccessControl.grantRole(0, user1);
    // }

    // function test_revert_initializeTwice() public {
    //     vm.expectRevert();
    //     hookTargetAccessControl.initialize(admin);
    // }
}
