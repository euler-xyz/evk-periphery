// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {HookTargetStakeDelegator} from "../../src/HookTarget/HookTargetStakeDelegator.sol";
import {IRewardVaultFactory, IRewardVault} from "../../src/HookTarget/HookTargetStakeDelegator.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {console} from "forge-std/console.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";

import "evk/EVault/shared/Constants.sol";

contract HookTargetStakeDelegatorTest is EVaultTestBase {
    HookTargetStakeDelegator public hookTargetStakeDelegator;
    address public user;
    uint256 public forkId;

    address public rewardVaultFactory = 0x94Ad6Ac84f6C6FbA8b8CCbD71d9f4f101def52a8;
    address public rewardVault;

    function setUp() public override {
        string memory rpc = "https://rpc.berachain.com/";
        uint256 blockNumber = 3087244;
        forkId = vm.createSelectFork(rpc, blockNumber);

        super.setUp();

        user = makeAddr("user");

        hookTargetStakeDelegator = new HookTargetStakeDelegator(address(eTST), address(rewardVaultFactory));
        rewardVault =
            IRewardVaultFactory(rewardVaultFactory).createRewardVault(address(hookTargetStakeDelegator.erc20()));
        eTST.setHookConfig(
            address(hookTargetStakeDelegator),
            (
                OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_REPAY | OP_REPAY_WITH_SHARES | OP_TRANSFER
                    | OP_VAULT_STATUS_CHECK
            )
        );

        assetTST.mint(user, 1000);
    }

    function test_HookTargetStakeDelegator_deposit() public {
        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);
    }

    function test_HookTargetStakeDelegator_withdraw() public {
        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user);

        eTST.withdraw(1000, user, user);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user), 0);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);
    }

    function test_HookTargetStakeDelegator_transfer() public {
        address user2 = makeAddr("user2");

        vm.startPrank(user);
        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user);

        eTST.transfer(user2, 1000);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user), 0);
        assertEq(eTST.balanceOf(user2), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 1000);

        vm.startPrank(user2);
        eTST.withdraw(1000, user2, user2);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2), 0);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 0);
    }

    function test_HookTargetStakeDelegator_subaccount() public {
        address user_subaccount = address(uint160(user) ^ 0x10);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0].onBehalfOfAccount = user;
        items[0].targetContract = address(eTST);
        items[0].value = 0;
        items[0].data = abi.encodeWithSelector(eTST.deposit.selector, 1000, user_subaccount);

        evc.batch(items);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user_subaccount), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user_subaccount, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);

        address user2 = makeAddr("user2");

        vm.startPrank(user);

        IEVC.BatchItem[] memory items2 = new IEVC.BatchItem[](1);

        items2[0].onBehalfOfAccount = user_subaccount;
        items2[0].targetContract = address(eTST);
        items2[0].value = 0;
        items2[0].data = abi.encodeWithSelector(eTST.transfer.selector, user2, 1000);

        evc.batch(items2);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user_subaccount), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user_subaccount, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 1000);
    }

    function test_HookTargetStakeDelegator_transfer_subaccount() public {
        address user_subaccount = address(uint160(user) ^ 0x10);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0].onBehalfOfAccount = user;
        items[0].targetContract = address(eTST);
        items[0].value = 0;
        items[0].data = abi.encodeWithSelector(eTST.deposit.selector, 1000, user_subaccount);

        evc.batch(items);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user_subaccount), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user_subaccount, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);

        vm.startPrank(user);

        IEVC.BatchItem[] memory items2 = new IEVC.BatchItem[](1);

        items2[0].onBehalfOfAccount = user_subaccount;
        items2[0].targetContract = address(eTST);
        items2[0].value = 0;
        items2[0].data = abi.encodeWithSelector(eTST.transfer.selector, user, 1000);

        evc.batch(items2);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user_subaccount), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user_subaccount, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);

        vm.startPrank(user);

        IEVC.BatchItem[] memory items3 = new IEVC.BatchItem[](1);
        items3[0].onBehalfOfAccount = user;
        items3[0].targetContract = address(eTST);
        items3[0].value = 0;
        items3[0].data = abi.encodeWithSelector(eTST.transfer.selector, user_subaccount, 1000);

        evc.batch(items3);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user_subaccount), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user_subaccount, address(hookTargetStakeDelegator)), 0);
    }

    function test_HookTargetStakeDelegator_deposit_on_behalf_of_subaccount() public {
        address user2 = makeAddr("user2");
        address user2_subaccount1 = address(uint160(user2) ^ 0x1);
        address user2_subaccount2 = address(uint160(user2) ^ 0x2);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user2_subaccount1);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2_subaccount1), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);

        vm.startPrank(user2);

        IEVC.BatchItem[] memory items2 = new IEVC.BatchItem[](1);

        items2[0].onBehalfOfAccount = user2_subaccount1;
        items2[0].targetContract = address(eTST);
        items2[0].value = 0;
        items2[0].data = abi.encodeWithSelector(eTST.transfer.selector, user2_subaccount2, 1000);

        evc.batch(items2);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2_subaccount1), 0);
        assertEq(eTST.balanceOf(user2_subaccount2), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount2, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 1000);

        vm.startPrank(user2);

        IEVC.BatchItem[] memory items3 = new IEVC.BatchItem[](1);

        items3[0].onBehalfOfAccount = user2_subaccount2;
        items3[0].targetContract = address(eTST);
        items3[0].value = 0;
        items3[0].data = abi.encodeWithSelector(eTST.transfer.selector, user2, 1000);

        evc.batch(items3);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2_subaccount2), 0);
        assertEq(eTST.balanceOf(user2), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount2, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 1000);
    }

    function test_HookTargetStakeDelegator_deposit_into_subaccount() public {
        address user2 = makeAddr("user2");
        address user2_subaccount1 = address(uint160(user2) ^ 0x1);

        assetTST.mint(user, 1000);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 2000);
        eTST.deposit(2000, user);

        vm.stopPrank();

        assetTST.mint(user2, 1000);

        vm.startPrank(user2);

        // deposit into the subaccount
        assetTST.approve(address(eTST), 1000);
        eTST.deposit(500, user2_subaccount1);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.balanceOf(user2_subaccount1), 500);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 2500);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 500);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 0);

        // register user2 as an EVC owner by performing an empty call on the EVC
        vm.prank(user2);
        evc.call(address(0), user2, 0, "");

        vm.startPrank(user2);
        eTST.deposit(500, user2_subaccount1);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2), 0);
        assertEq(eTST.balanceOf(user2_subaccount1), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 3000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 1000);
    }

    function test_HookTargetStakeDelegator_withdraw_from_subaccount() public {
        address user2 = makeAddr("user2");
        address user2_subaccount1 = address(uint160(user2) ^ 0x1);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user2_subaccount1);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2_subaccount1), 1000);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);

        vm.startPrank(user2);

        evc.call(address(0), user2, 0, "");

        IEVC.BatchItem[] memory items2 = new IEVC.BatchItem[](1);

        items2[0].onBehalfOfAccount = user2_subaccount1;
        items2[0].targetContract = address(eTST);
        items2[0].value = 0;
        items2[0].data = abi.encodeWithSelector(eTST.withdraw.selector, 500, user2, user2_subaccount1);

        evc.batch(items2);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user2_subaccount1), 500);
        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 500);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2_subaccount1, address(hookTargetStakeDelegator)), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user2, address(hookTargetStakeDelegator)), 500);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);
    }

    function test_HookTargetStakeDelegator_withdraw_existing_position() public {
        eTST.setHookConfig(address(0), 0);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user), 1000);

        eTST.setHookConfig(
            address(hookTargetStakeDelegator),
            (
                OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_REPAY | OP_REPAY_WITH_SHARES | OP_TRANSFER
                    | OP_VAULT_STATUS_CHECK
            )
        );

        vm.startPrank(user);

        eTST.withdraw(1000, user, user);

        vm.stopPrank();

        assertEq(eTST.balanceOf(user), 0);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 0);
    }

    function test_hookTargetStakeDelegator_borrow_and_liquidation() public {
        address user2 = makeAddr("user2");
        address liquidator = makeAddr("liquidator");

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        assetTST.mint(liquidator, 10000);

        assetTST2.mint(user2, 1000);
        assetTST2.mint(liquidator, 1000);

        HookTargetStakeDelegator hookTargetStakeDelegator2 =
            new HookTargetStakeDelegator(address(eTST2), address(rewardVaultFactory));
        address rewardVault2 =
            IRewardVaultFactory(rewardVaultFactory).createRewardVault(address(hookTargetStakeDelegator2.erc20()));
        eTST2.setHookConfig(
            address(hookTargetStakeDelegator2),
            (
                OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_REPAY | OP_REPAY_WITH_SHARES | OP_TRANSFER
                    | OP_VAULT_STATUS_CHECK
            )
        );

        eTST2.setLTV(address(eTST), 0.5e4, 0.5e4, 0);

        vm.startPrank(user2);

        assetTST2.approve(address(eTST2), 1000);
        eTST2.deposit(1000, user2);

        vm.stopPrank();

        assertEq(hookTargetStakeDelegator2.erc20().balanceOf(rewardVault2), 1000);
        assertEq(IRewardVault(rewardVault2).getDelegateStake(user2, address(hookTargetStakeDelegator2)), 1000);

        vm.startPrank(user);

        assetTST.approve(address(eTST), 1000);
        eTST.deposit(1000, user);

        evc.enableCollateral(user, address(eTST));
        evc.enableController(user, address(eTST2));

        eTST2.borrow(499, user);

        vm.stopPrank();

        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 1000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);

        assertEq(hookTargetStakeDelegator2.erc20().balanceOf(rewardVault2), 1000);
        assertEq(IRewardVault(rewardVault2).getDelegateStake(user2, address(hookTargetStakeDelegator2)), 1000);

        oracle.setPrice(address(eTST), unitOfAccount, 0.95e18);

        vm.startPrank(liquidator);

        evc.enableCollateral(liquidator, address(eTST));
        evc.enableController(liquidator, address(eTST2));

        assetTST.approve(address(eTST), 10000);
        eTST.deposit(10000, liquidator);

        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 11000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(liquidator, address(hookTargetStakeDelegator)), 10000);
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000);

        (, uint256 maxYield) = eTST2.checkLiquidation(liquidator, user, address(eTST));

        eTST2.liquidate(user, address(eTST), 499, 0);

        vm.stopPrank();

        assertEq(hookTargetStakeDelegator.erc20().balanceOf(rewardVault), 11000);
        assertEq(
            IRewardVault(rewardVault).getDelegateStake(liquidator, address(hookTargetStakeDelegator)), 10000 + maxYield
        );
        assertEq(IRewardVault(rewardVault).getDelegateStake(user, address(hookTargetStakeDelegator)), 1000 - maxYield);

        assertEq(hookTargetStakeDelegator2.erc20().balanceOf(rewardVault2), 1000);
        assertEq(IRewardVault(rewardVault2).getDelegateStake(user2, address(hookTargetStakeDelegator2)), 1000);
    }
}
