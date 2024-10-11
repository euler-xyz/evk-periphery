// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Vm, Test} from "forge-std/Test.sol";
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";
import {ERC20Mintable} from "../../script/utils/ScriptUtils.s.sol";
import {RewardToken} from "../../src/ERC20/deployed/RewardToken.sol";
import {ERC20WrapperLocked, EVCUtil, Ownable} from "../../src/ERC20/implementation/ERC20WrapperLocked.sol";

contract RewardTokenTest is Test {
    address owner = makeAddr("owner");
    address remainderReceiver = makeAddr("remainderReceiver");
    EthereumVaultConnector evc;
    ERC20Mintable erc20Mintable;
    RewardToken rewardToken;

    function setUp() public {
        evc = new EthereumVaultConnector();
        erc20Mintable = new ERC20Mintable(owner, "ERC20Mintable", "ERC20Mintable", 18);
        rewardToken = new RewardToken(
            address(evc), owner, remainderReceiver, address(erc20Mintable), "RewardToken", "RewardToken"
        );
    }

    function mint(address account, uint256 amount) internal {
        vm.prank(owner);
        erc20Mintable.mint(account, amount);

        vm.prank(account);
        erc20Mintable.approve(address(rewardToken), amount);
    }

    function test_setRemainderReceiver(address nonOwner, address newRemainderReceiver) external {
        vm.assume(nonOwner != owner && nonOwner != address(evc));
        vm.assume(newRemainderReceiver != address(0));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        rewardToken.setRemainderReceiver(newRemainderReceiver);

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false, address(rewardToken));
        emit ERC20WrapperLocked.RemainderReceiverSet(newRemainderReceiver);
        rewardToken.setRemainderReceiver(newRemainderReceiver);
        assertEq(rewardToken.remainderReceiver(), newRemainderReceiver);
    }

    function test_setWhitelistStatus(address nonOwner, address account, bool status) external {
        vm.assume(nonOwner != owner && nonOwner != address(evc));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        rewardToken.setWhitelistStatus(account, status);

        vm.startPrank(owner);
        bool statusWillChange = status != rewardToken.isWhitelisted(account);
        if (statusWillChange) {
            vm.expectEmit(true, false, false, true, address(rewardToken));
            emit ERC20WrapperLocked.WhitelistStatus(account, status);
        }
        rewardToken.setWhitelistStatus(account, status);
        assertEq(rewardToken.isWhitelisted(account), status);
    }

    function test_setWhitelistStatus_lockCreated(address account, uint256 amount, uint256 timestamp) external {
        vm.assume(owner != address(evc));
        vm.assume(account != address(0) && account != owner && account != address(rewardToken));

        vm.warp(timestamp);
        mint(owner, amount);
        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, true);
        rewardToken.setWhitelistStatus(account, true);
        rewardToken.depositFor(account, amount);

        assertEq(rewardToken.getLockedAmountsLength(account), 0);
        if (amount != 0) {
            vm.expectEmit(true, false, false, true, address(rewardToken));
            emit ERC20WrapperLocked.LockCreated(account, normalizedTimestamp);
        }
        rewardToken.setWhitelistStatus(account, false);
        if (amount != 0) {
            assertEq(rewardToken.getLockedAmountsLength(account), 1);
            assertEq(rewardToken.getLockedAmountsLockTimestamps(account)[0], normalizedTimestamp);
            assertEq(rewardToken.getLockedAmountByLockTimestamp(account, normalizedTimestamp), amount);
            (uint256[] memory lockTimestamps, uint256[] memory amounts) = rewardToken.getLockedAmounts(account);
            assertEq(lockTimestamps.length, 1);
            assertEq(lockTimestamps[0], normalizedTimestamp);
            assertEq(amounts[0], amount);
        }
    }

    function test_setWhitelistStatus_lockRemoved(
        address account,
        uint32 amount,
        uint8 i,
        uint32 timestamp,
        uint256 delta
    ) external {
        vm.assume(account != address(0) && account != owner && account != address(rewardToken));
        vm.assume(i > 0);
        delta = bound(delta, 0, 2 days);

        vm.warp(timestamp);
        mint(owner, uint256(amount) * i);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, true);
        rewardToken.depositFor(owner, uint256(amount) * i);

        Vm.Log[] memory logs;
        uint256 previousNormalizedTimestamp = block.timestamp - (block.timestamp % 1 days);
        for (uint256 j = 0; j < i; j++) {
            uint256 previousLockAmount =
                rewardToken.getLockedAmountByLockTimestamp(account, previousNormalizedTimestamp);
            uint256 newNormalizedTimestamp = block.timestamp - (block.timestamp % 1 days);

            if (amount != 0 && (j == 0 || newNormalizedTimestamp != previousNormalizedTimestamp)) {
                vm.expectEmit(true, false, false, true, address(rewardToken));
                emit ERC20WrapperLocked.LockCreated(account, newNormalizedTimestamp);
            }

            vm.recordLogs();
            rewardToken.transfer(account, amount);

            if (amount != 0) {
                if (j == 0 || newNormalizedTimestamp != previousNormalizedTimestamp) {
                    assertEq(rewardToken.getLockedAmountByLockTimestamp(account, newNormalizedTimestamp), amount);
                } else {
                    logs = vm.getRecordedLogs();
                    assertEq(logs.length, 1);
                    assertEq(
                        rewardToken.getLockedAmountByLockTimestamp(account, newNormalizedTimestamp),
                        previousLockAmount + amount
                    );
                }
            }

            previousNormalizedTimestamp = newNormalizedTimestamp;
            vm.warp(block.timestamp + delta);
        }

        uint256[] memory lockTimestamps1 = rewardToken.getLockedAmountsLockTimestamps(account);
        if (amount != 0) {
            (uint256[] memory lockTimestamps2, uint256[] memory amounts) = rewardToken.getLockedAmounts(account);

            assertEq(rewardToken.getLockedAmountsLength(account), lockTimestamps1.length);
            assertEq(lockTimestamps1.length, lockTimestamps2.length);
            for (uint256 j = 0; j < lockTimestamps1.length; j++) {
                assertEq(lockTimestamps1[j], lockTimestamps2[j]);
                assertEq(amounts[j], rewardToken.getLockedAmountByLockTimestamp(account, lockTimestamps1[j]));
            }
        }

        vm.recordLogs();
        rewardToken.setWhitelistStatus(account, true);
        logs = vm.getRecordedLogs();

        if (lockTimestamps1.length == 0) {
            assertEq(logs.length, 1);
        } else {
            assertEq(logs.length, lockTimestamps1.length + 1);
            for (uint256 j = 0; j < lockTimestamps1.length; j++) {
                assertEq(logs[j].topics.length, 2);
                assertEq(logs[j].topics[0], keccak256("LockRemoved(address,uint256)"));
                assertEq(logs[j].topics[1], bytes32(uint256(uint160(account))));
                assertEq(abi.decode(logs[j].data, (uint256)), lockTimestamps1[j]);
            }
        }
        assertEq(rewardToken.getLockedAmountsLength(account), 0);
    }

    function test_depositFor_withdrawTo_transfer_transferFrom(
        bool isCallerWhitelisted,
        bool isAccountWhitelisted,
        bool isReceiverWhitelisted,
        address caller,
        address account,
        address receiver,
        uint256 amount
    ) external {
        vm.assume(
            caller != address(0) && account != address(0) && caller != account && caller != address(rewardToken)
                && account != address(rewardToken) && caller != address(evc) && account != address(evc)
        );
        vm.assume(
            receiver != address(0) && receiver != caller && receiver != account && receiver != remainderReceiver
                && receiver != address(evc) && receiver != address(rewardToken)
        );
        vm.assume(amount > 0 && amount < type(uint256).max / 1e18);

        mint(caller, amount);

        vm.startPrank(owner);
        if (isCallerWhitelisted) rewardToken.setWhitelistStatus(caller, true);
        if (isAccountWhitelisted) rewardToken.setWhitelistStatus(account, true);
        if (isReceiverWhitelisted) rewardToken.setWhitelistStatus(receiver, true);
        vm.stopPrank();

        if (isCallerWhitelisted) {
            assertEq(erc20Mintable.balanceOf(caller), amount);
            assertEq(erc20Mintable.balanceOf(account), 0);
            vm.prank(caller);
            rewardToken.depositFor(account, amount);
            assertEq(erc20Mintable.balanceOf(caller), 0);
            assertEq(rewardToken.balanceOf(account), amount);

            uint256 snapshot = vm.snapshot();

            if (isAccountWhitelisted) {
                vm.startPrank(account);
                rewardToken.withdrawTo(receiver, amount);
                assertEq(erc20Mintable.balanceOf(receiver), amount);
                assertEq(rewardToken.balanceOf(account), 0);

                vm.revertTo(snapshot);
                rewardToken.transfer(receiver, amount);
                assertEq(rewardToken.balanceOf(receiver), amount);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(rewardToken.getLockedAmountsLength(receiver), isReceiverWhitelisted ? 0 : 1);

                vm.revertTo(snapshot);
                rewardToken.approve(receiver, amount);
                vm.stopPrank();

                vm.prank(receiver);
                rewardToken.transferFrom(account, receiver, amount);
                assertEq(rewardToken.balanceOf(receiver), amount);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(rewardToken.getLockedAmountsLength(receiver), isReceiverWhitelisted ? 0 : 1);
            } else {
                vm.startPrank(account);
                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                rewardToken.withdrawTo(receiver, amount);

                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                rewardToken.transfer(receiver, amount);

                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                rewardToken.withdrawTo(receiver, amount);

                assertEq(rewardToken.getLockedAmountsLength(account), 1);
                rewardToken.withdrawToByLockTimestamp(receiver, 0, true);
                assertEq(erc20Mintable.balanceOf(receiver), amount / 5);
                assertEq(erc20Mintable.balanceOf(remainderReceiver), amount - amount / 5);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(rewardToken.getLockedAmountsLength(account), 0);
            }
        } else {
            vm.prank(caller);
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            rewardToken.depositFor(account, amount);
        }
    }

    function test_withdrawToByLockTimestamp(
        address account,
        address receiver,
        bool allowRemainderLoss,
        uint256 amount,
        uint32 timestamp,
        uint256 delta
    ) external {
        vm.assume(
            account != address(0) && account != owner && account != address(rewardToken) && account != address(evc)
        );
        vm.assume(receiver != address(0) && receiver != account && receiver != remainderReceiver);
        vm.assume(amount < type(uint256).max / 1e18);
        delta = bound(delta, 0, 200 days);

        vm.warp(timestamp);
        mint(owner, amount);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, true);
        rewardToken.depositFor(account, amount);
        vm.stopPrank();

        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);
        vm.warp(normalizedTimestamp + delta);
        assertEq(rewardToken.getLockedAmountsLength(account), amount != 0 ? 1 : 0);
        assertEq(rewardToken.getLockedAmountByLockTimestamp(account, normalizedTimestamp), amount);
        assertEq(rewardToken.balanceOf(account), amount);

        vm.startPrank(account);
        uint256 expectedAmount;
        if (delta <= 1 days) {
            expectedAmount = amount / 5;
        } else if (delta >= 180 days) {
            expectedAmount = amount;
        } else {
            expectedAmount = ((delta - 1 days) * 0.8e18 / 179 days + 0.2e18) * amount / 1e18;
        }
        if (expectedAmount != amount && !allowRemainderLoss) {
            vm.expectRevert(abi.encodeWithSelector(ERC20WrapperLocked.RemainderLossNotAllowed.selector));
            rewardToken.withdrawToByLockTimestamp(receiver, normalizedTimestamp, allowRemainderLoss);
        } else {
            rewardToken.withdrawToByLockTimestamp(receiver, normalizedTimestamp, allowRemainderLoss);
            assertEq(erc20Mintable.balanceOf(receiver), expectedAmount);
            assertEq(erc20Mintable.balanceOf(remainderReceiver), amount - expectedAmount);
            assertEq(rewardToken.balanceOf(account), 0);
            assertEq(rewardToken.getLockedAmountsLength(account), 0);
        }
    }

    function test_remainderReceiverIsZero(
        address account,
        address receiver,
        bool allowRemainderLoss,
        uint256 amount,
        uint32 timestamp,
        uint256 delta
    ) external {
        rewardToken =
            new RewardToken(address(evc), owner, address(0), address(erc20Mintable), "RewardToken", "RewardToken");
        vm.assume(
            account != address(0) && account != owner && account != address(rewardToken) && account != address(evc)
        );
        vm.assume(receiver != address(0) && receiver != account && receiver != remainderReceiver && receiver != owner);
        vm.assume(amount < type(uint256).max / 1e18);
        delta = bound(delta, 0, 200 days);

        vm.warp(timestamp);
        mint(owner, amount);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, true);
        rewardToken.depositFor(account, amount);
        vm.stopPrank();

        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);
        vm.warp(normalizedTimestamp + delta);
        assertEq(rewardToken.getLockedAmountsLength(account), amount != 0 ? 1 : 0);
        assertEq(rewardToken.getLockedAmountByLockTimestamp(account, normalizedTimestamp), amount);
        assertEq(rewardToken.balanceOf(account), amount);

        vm.startPrank(account);
        uint256 expectedAmount;
        if (delta <= 1 days) {
            expectedAmount = amount / 5;
        } else if (delta >= 180 days) {
            expectedAmount = amount;
        } else {
            expectedAmount = ((delta - 1 days) * 0.8e18 / 179 days + 0.2e18) * amount / 1e18;
        }
        if (expectedAmount != amount && !allowRemainderLoss) {
            vm.expectRevert(abi.encodeWithSelector(ERC20WrapperLocked.RemainderLossNotAllowed.selector));
            rewardToken.withdrawToByLockTimestamp(receiver, normalizedTimestamp, allowRemainderLoss);
        } else {
            rewardToken.withdrawToByLockTimestamp(receiver, normalizedTimestamp, allowRemainderLoss);
            assertEq(erc20Mintable.balanceOf(receiver), expectedAmount);
            assertEq(erc20Mintable.balanceOf(owner), amount - expectedAmount);
            assertEq(rewardToken.balanceOf(account), 0);
            assertEq(rewardToken.getLockedAmountsLength(account), 0);
        }
    }
}
