// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";
import {ReadOnlyProxy} from "../../src/Governor/ReadOnlyProxy.sol";

import {Errors} from "evk/EVault/shared/Errors.sol";

contract FactoryGovernorTests is EVaultTestBase {
    address depositor;
    address guardian;
    address guardian2;
    address unpauseAdmin;
    address unpauseAdmin2;

    FactoryGovernor factoryGovernor;

    function setUp() public virtual override {
        super.setUp();

        depositor = makeAddr("depositor");
        guardian = makeAddr("guardian");
        guardian2 = makeAddr("guardian2");
        unpauseAdmin = makeAddr("unpauseAdmin");
        unpauseAdmin2 = makeAddr("unpauseAdmin2");

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        vm.stopPrank();

        factoryGovernor = new FactoryGovernor(admin);

        bytes32 guardianRole = factoryGovernor.PAUSE_GUARDIAN_ROLE();
        vm.prank(admin);
        factoryGovernor.grantRole(guardianRole, guardian);

        bytes32 unpauseAdminRole = factoryGovernor.UNPAUSE_ADMIN_ROLE();
        vm.prank(admin);
        factoryGovernor.grantRole(unpauseAdminRole, unpauseAdmin);

        vm.prank(admin);
        factory.setUpgradeAdmin(address(factoryGovernor));
    }

    function test_FactoryGovernor_triggerEmergencyByGuardian() external {
        address oldImplementation = factory.implementation();

        uint256 balance = eTST.balanceOf(depositor);
        assertEq(balance, 100e18);

        vm.prank(depositor);
        eTST.deposit(1e18, depositor);

        uint256 totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 101e18);

        vm.prank(guardian);
        vm.expectEmit(true, false, false, false);
        emit FactoryGovernor.Paused(guardian, address(factory), address(1));
        factoryGovernor.pause(address(factory));

        // balanceOf is embedded in EVault
        balance = eTST.balanceOf(depositor);
        assertEq(balance, 101e18);

        // totalSupply is forwarded to an EVault module
        totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 101e18);

        string memory name = eTST.name();
        assertEq(keccak256(bytes(name)), keccak256("EVK Vault eTST-1"));

        // state mutation is not allowed
        vm.prank(depositor);
        vm.expectRevert("contract is in read-only mode");
        eTST.deposit(1e18, depositor);

        // admin can roll back changes by installing previous implementations
        vm.prank(admin);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setImplementation, (oldImplementation)));

        vm.prank(depositor);
        eTST.deposit(1e18, depositor);
        assertEq(eTST.balanceOf(depositor), 102e18);
    }

    function test_FactoryGovernor_unauthorizedCantTriggePause() external {
        vm.prank(admin);
        vm.expectRevert();
        factoryGovernor.pause(address(factory));

        vm.prank(depositor);
        vm.expectRevert();
        factoryGovernor.pause(address(factory));

        vm.prank(unpauseAdmin);
        vm.expectRevert();
        factoryGovernor.pause(address(factory));
    }

    function test_FactoryGovernor_unpauseAdminCanUnpause() external {
        // not paused yet
        vm.prank(unpauseAdmin);
        vm.expectRevert("not paused");
        factoryGovernor.unpause(address(factory));

        address oldImplementation = factory.implementation();
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        vm.prank(unpauseAdmin);
        vm.expectEmit(true, false, false, false);
        emit FactoryGovernor.Unpaused(unpauseAdmin, address(factory), oldImplementation);
        factoryGovernor.unpause(address(factory));

        // not paused anymore
        vm.prank(unpauseAdmin);
        vm.expectRevert("not paused");
        factoryGovernor.unpause(address(factory));

        assertEq(factory.implementation(), oldImplementation);

        vm.prank(depositor);
        eTST.deposit(1e18, depositor);
        assertEq(eTST.balanceOf(depositor), 101e18);
    }

    function test_FactoryGovernor_unauthorizedCantTriggeUnpause() external {
        vm.prank(admin);
        vm.expectRevert();
        factoryGovernor.unpause(address(factory));

        vm.prank(depositor);
        vm.expectRevert();
        factoryGovernor.unpause(address(factory));

        vm.prank(guardian);
        vm.expectRevert();
        factoryGovernor.unpause(address(factory));
    }

    function test_FactoryGovernor_triggerEmergencyByAdmin() external {
        uint256 balance = eTST.balanceOf(depositor);
        assertEq(balance, 100e18);

        vm.prank(depositor);
        eTST.deposit(1e18, depositor);

        uint256 totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 101e18);

        bytes32 guardianRole = factoryGovernor.PAUSE_GUARDIAN_ROLE();
        vm.prank(admin);
        factoryGovernor.grantRole(guardianRole, admin);

        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit FactoryGovernor.Paused(admin, address(factory), address(1));
        factoryGovernor.pause(address(factory));

        // balanceOf is embedded in EVault
        balance = eTST.balanceOf(depositor);
        assertEq(balance, 101e18);

        // totalSupply is forwarded to an EVault module
        totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 101e18);

        // state mutation is not allowed
        vm.prank(depositor);
        vm.expectRevert("contract is in read-only mode");
        eTST.deposit(1e18, depositor);
    }

    function test_FactoryGovernor_triggerEmergencyMultipleTimes() external {
        vm.prank(guardian);
        vm.expectEmit(true, false, false, false);
        emit FactoryGovernor.Paused(guardian, address(factory), address(1));
        factoryGovernor.pause(address(factory));

        vm.prank(guardian);
        vm.expectRevert("already paused");
        factoryGovernor.pause(address(factory));
    }

    function test_FactoryGovernor_adminCanUpgradeImplementation() external {
        address newImplementation = makeAddr("newImplementation");
        vm.etch(newImplementation, "123");

        // admin can't call factory directly
        vm.prank(admin);
        vm.expectRevert();
        factory.setImplementation(newImplementation);

        // but can set implementation through FactoryGovernor
        vm.prank(admin);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setImplementation, (newImplementation)));

        assertEq(factory.implementation(), newImplementation);
    }

    function test_FactoryGovernor_adminCanChangeTheFactoryAdmin() external {
        address newFactoryAdmin = makeAddr("newFactoryAdmin");

        vm.prank(admin);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setUpgradeAdmin, (newFactoryAdmin)));

        assertEq(factory.upgradeAdmin(), newFactoryAdmin);

        // factory governor has no rights now

        vm.prank(guardian);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        factoryGovernor.pause(address(factory));
    }

    function test_FactoryGovernor_onlyAdminCanDoAdminCall() external {
        address newImplementation = makeAddr("newImplementation");
        vm.etch(newImplementation, "123");

        // but can set implementation through FactoryGovernor
        vm.prank(guardian);
        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setImplementation, (newImplementation)));

        // install new factory governor admin

        address newAdmin = makeAddr("newAdmin");
        bytes32 adminRole = factoryGovernor.DEFAULT_ADMIN_ROLE();

        vm.prank(admin);
        factoryGovernor.grantRole(adminRole, newAdmin);
        vm.prank(newAdmin);
        factoryGovernor.revokeRole(adminRole, admin);

        // old admin has no access
        vm.prank(admin);
        vm.expectRevert();
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setImplementation, (newImplementation)));

        vm.prank(newAdmin);
        factoryGovernor.adminCall(address(factory), abi.encodeCall(factory.setImplementation, (newImplementation)));

        assertEq(factory.implementation(), newImplementation);
    }

    function test_FactoryGovernor_addGuardians() external {
        bytes32 guardianRole = factoryGovernor.PAUSE_GUARDIAN_ROLE();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, guardian2, guardianRole)
        );
        vm.prank(guardian2);
        factoryGovernor.pause(address(factory));

        vm.prank(admin);
        factoryGovernor.grantRole(guardianRole, guardian2);

        vm.prank(guardian2);
        factoryGovernor.pause(address(factory));
    }

    function test_FactoryGovernor_removeGuardians() external {
        bytes32 guardianRole = factoryGovernor.PAUSE_GUARDIAN_ROLE();

        vm.prank(admin);
        factoryGovernor.revokeRole(guardianRole, guardian);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, guardian, guardianRole)
        );
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));
    }

    function test_FactoryGovernor_addUnpauseAdmins() external {
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        bytes32 unpauseAdminRole = factoryGovernor.UNPAUSE_ADMIN_ROLE();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unpauseAdmin2, unpauseAdminRole
            )
        );
        vm.prank(unpauseAdmin2);
        factoryGovernor.unpause(address(factory));

        vm.prank(admin);
        factoryGovernor.grantRole(unpauseAdminRole, unpauseAdmin2);

        vm.prank(unpauseAdmin2);
        factoryGovernor.unpause(address(factory));
    }

    function test_FactoryGovernor_removeUnpauseAdmins() external {
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        bytes32 unpauseAdminRole = factoryGovernor.UNPAUSE_ADMIN_ROLE();

        vm.prank(admin);
        factoryGovernor.revokeRole(unpauseAdminRole, unpauseAdmin);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unpauseAdmin, unpauseAdminRole
            )
        );
        vm.prank(unpauseAdmin);
        factoryGovernor.unpause(address(factory));
    }

    function test_FactoryGovernor_proxyDelegateViewIsNotCallableExternally() external {
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        (bool success, bytes memory data) = address(eTST).call(abi.encodeCall(ReadOnlyProxy.roProxyDelegateView, ("")));
        assertFalse(success);
        assertEq(keccak256(data), keccak256(abi.encodeWithSignature("Error(string)", "unauthorized")));
    }

    function test_FactoryGovernor_roProxyImplementation() external {
        address oldImplementation = factory.implementation();
        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        assertEq(oldImplementation, ReadOnlyProxy(factory.implementation()).roProxyImplementation());
    }
}
