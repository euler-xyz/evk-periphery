// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";

import {FactoryGovernor} from "../../src/Governor/FactoryGovernor.sol";

contract FactoryGovernorTests is EVaultTestBase {
    address depositor;
    address guardian;

    FactoryGovernor factoryGovernor;

    function setUp() public virtual override {
        super.setUp();

        depositor = makeAddr("depositor");
        guardian = makeAddr("guardian");

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        vm.stopPrank();

        address[] memory guardians = new address[](1);
        guardians[0] = guardian;
        factoryGovernor = new FactoryGovernor(address(this), guardians);

        vm.prank(admin);
        factory.setUpgradeAdmin(address(factoryGovernor));
    }

    function test_triggerEmergencyByGuardian() external {
        uint256 balance = eTST.balanceOf(depositor);
        assertEq(balance, 100e18);

        uint256 totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 100e18);

        vm.prank(guardian);
        factoryGovernor.pause(address(factory));

        // balanceOf is embedded in EVault
        balance = eTST.balanceOf(depositor);
        assertEq(balance, 100e18);

        // totalSupply is forwarded to an EVault module
        totalSupply = eTST.totalSupply();
        assertEq(totalSupply, 100e18);

        vm.prank(depositor);
        vm.expectRevert("contract is in read-only mode");
        eTST.deposit(1e18, depositor);
    }
}
