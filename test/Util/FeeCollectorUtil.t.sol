// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {FeeFlowControllerEVK} from "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {FeeFlowControllerEVKTest} from "../FeeFlow/FeeFlowControllerEVK.t.sol";
import {FeeCollectorUtil} from "../../src/Util/FeeCollectorUtil.sol";
import {MockToken} from "../FeeFlow/lib/MockToken.sol";

contract FeeCollectorUtilTest is FeeFlowControllerEVKTest {
    FeeCollectorUtil feeCollector;
    address admin;
    address maintainer;
    MockVault vault1;
    MockVault vault2;
    MockVault vaultOtherUnderlying;

    function setUp() public override virtual {
        super.setUp();

        admin = makeAddr("admin");
        maintainer = makeAddr("maintainer");
        feeCollector = new FeeCollectorUtil(admin, address(paymentToken));

        bytes32 maintainerRole = feeCollector.MAINTAINER_ROLE();
        vm.prank(admin);
        feeCollector.grantRole(maintainerRole, maintainer);

        vault1 = new MockVault(paymentToken, address(feeCollector));
        vault2 = new MockVault(paymentToken, address(feeCollector));
        vaultOtherUnderlying = new MockVault(MockToken(address(1)), address(feeCollector));

        // deploy new controller with new hook data
        feeFlowController = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(feeCollector),
            abi.encodeCall(feeCollector.collectFees, ())
        );
        vm.prank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
    }

    function testVaultList() public {
        // no vaults 
        assertEq(feeCollector.getVaultsList().length, 0);

        // only maintainer can add vaults
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeCollector.MAINTAINER_ROLE()
            )
        );
        feeCollector.addToVaultsList(address(vault1));

        vm.prank(maintainer);
        vm.expectEmit();
        emit FeeCollectorUtil.VaultAdded(address(vault1));
        feeCollector.addToVaultsList(address(vault1));
        assertEq(feeCollector.getVaultsList().length, 1);
        assertTrue(feeCollector.isInVaultsList(address(vault1)));
        assertTrue(!feeCollector.isInVaultsList(address(vault2)));

        // only maintainer can remove vaults
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeCollector.MAINTAINER_ROLE()
            )
        );
        feeCollector.removeFromVaultsList(address(vault1));

        vm.prank(maintainer);
        vm.expectEmit();
        emit FeeCollectorUtil.VaultRemoved(address(vault1));
        bool result = feeCollector.removeFromVaultsList(address(vault1));
        assertTrue(result);
        assertEq(feeCollector.getVaultsList().length, 0);
        assertTrue(!feeCollector.isInVaultsList(address(vault1)));
        assertTrue(!feeCollector.isInVaultsList(address(vault2)));

        // can't add vault with another underlying
        vm.prank(maintainer);
        vm.expectRevert(FeeCollectorUtil.InvalidVault.selector);
        feeCollector.addToVaultsList(address(vaultOtherUnderlying));

        // removing vault that's not in the list returns false
        vm.prank(maintainer);
        result = feeCollector.removeFromVaultsList(address(vault1));
        assertTrue(!result);
    }

    function testRecoverTokens() public {
        deal(address(feeCollector), 1 ether);
        deal(address(paymentToken), address(feeCollector), 2e18);

        // only admin can recover
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeCollector.DEFAULT_ADMIN_ROLE()
            )
        );
        feeCollector.recoverToken(address(0), admin, 1 ether);

        vm.startPrank(admin);
        // recover too much ether
        vm.expectRevert("Native currency recovery failed");
        feeCollector.recoverToken(address(0), admin, 1 ether + 1);

        // recover ether
        assertEq(admin.balance, 0);
        feeCollector.recoverToken(address(0), admin, 1 ether);
        assertEq(admin.balance, 1 ether);
        // recover too much token
        vm.expectRevert();
        feeCollector.recoverToken(address(paymentToken), admin, 2 ether + 1);

        // recover token
        assertEq(paymentToken.balanceOf(admin), 0);
        feeCollector.recoverToken(address(paymentToken), admin, 2 ether);
        assertEq(paymentToken.balanceOf(admin), 2 ether);
    }

    function testIntegrationWithFeeFlow() public {
        mintTokensToBatchBuyer();

        vault1.mockSetFeeAmount(1e18);
        vault2.mockSetFeeAmount(2e18);

        vm.startPrank(maintainer);
        feeCollector.addToVaultsList(address(vault1));
        feeCollector.addToVaultsList(address(vault2));
        vm.stopPrank();

        assertEq(paymentToken.balanceOf(address(feeCollector)), 0);
        vm.prank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        assertEq(paymentToken.balanceOf(address(feeCollector)), 3e18);
    }
}


contract MockVault {
    MockToken underlying;
    address feeReceiver;
    uint256 feesAmount;
    constructor(MockToken underlying_, address feeReceiver_) {
        underlying = underlying_;
        feeReceiver = feeReceiver_;
    }

    function mockSetFeeAmount(uint256 newAmount) public {
        feesAmount = newAmount;
    }

    function convertFees() public {
        underlying.mint(feeReceiver, feesAmount);
    }

    function asset() external view returns(address) {
        return address(underlying);
    }
}