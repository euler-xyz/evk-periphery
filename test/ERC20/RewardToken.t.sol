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
        vm.assume(newRemainderReceiver != rewardToken.remainderReceiver());

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        rewardToken.setRemainderReceiver(newRemainderReceiver);

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false, address(rewardToken));
        emit ERC20WrapperLocked.RemainderReceiverSet(newRemainderReceiver);
        rewardToken.setRemainderReceiver(newRemainderReceiver);
        assertEq(rewardToken.remainderReceiver(), newRemainderReceiver);
    }

    function test_setWhitelistStatus_owner(address nonOwner, address account, uint8 status) external {
        vm.assume(status < 3);
        vm.assume(nonOwner != owner && nonOwner != address(evc));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(status));

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
        rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.NONE);
        vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
        rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.LOWER);
        vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
        rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.HIGHER);

        if (ERC20WrapperLocked.WhitelistStatus(status) != rewardToken.whitelistStatus(account)) {
            vm.expectEmit(true, false, false, true, address(rewardToken));
            emit ERC20WrapperLocked.WhitelistStatusSet(account, ERC20WrapperLocked.WhitelistStatus(status));
        }
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(status));
        assertEq(uint8(rewardToken.whitelistStatus(account)), status);
    }

    function test_setWhitelistStatus_downgrade(address account, uint8 status) external {
        vm.assume(status < 3);
        vm.startPrank(owner);

        if (ERC20WrapperLocked.WhitelistStatus(status) != ERC20WrapperLocked.WhitelistStatus.NONE) {
            vm.expectEmit(true, false, false, true, address(rewardToken));
            emit ERC20WrapperLocked.WhitelistStatusSet(account, ERC20WrapperLocked.WhitelistStatus(status));
        }
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(status));
        assertEq(uint8(rewardToken.whitelistStatus(account)), status);
        vm.stopPrank();

        uint256 snapshot = vm.snapshotState();

        vm.startPrank(account);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, account));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus.NONE);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, account));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus.LOWER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, account));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus.HIGHER);

        if (ERC20WrapperLocked.WhitelistStatus(status) == ERC20WrapperLocked.WhitelistStatus.NONE) {
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.NONE);
        } else {
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.NONE);
            assertEq(uint8(rewardToken.whitelistStatus(account)), uint8(ERC20WrapperLocked.WhitelistStatus.NONE));
        }

        vm.revertToState(snapshot);
        if (ERC20WrapperLocked.WhitelistStatus(status) == ERC20WrapperLocked.WhitelistStatus.NONE) {
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.LOWER);
        } else {
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.LOWER);
            assertEq(uint8(rewardToken.whitelistStatus(account)), uint8(ERC20WrapperLocked.WhitelistStatus.LOWER));
        }

        vm.revertToState(snapshot);
        if (ERC20WrapperLocked.WhitelistStatus(status) == ERC20WrapperLocked.WhitelistStatus.HIGHER) {
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.HIGHER);
            assertEq(uint8(rewardToken.whitelistStatus(account)), uint8(ERC20WrapperLocked.WhitelistStatus.HIGHER));
        } else {
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            rewardToken.setWhitelistStatus(ERC20WrapperLocked.WhitelistStatus.HIGHER);
        }
    }

    function test_setWhitelistStatus_lockCreated(address account, uint256 amount, uint256 timestamp, uint8 status)
        external
    {
        vm.assume(owner != address(evc));
        vm.assume(account != address(0) && account != owner && account != address(rewardToken));
        vm.assume(status != 0 && status < 3);

        vm.warp(timestamp);
        mint(owner, amount);
        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, ERC20WrapperLocked.WhitelistStatus(status));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(status));

        if (ERC20WrapperLocked.WhitelistStatus(status) == ERC20WrapperLocked.WhitelistStatus.LOWER) {
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            rewardToken.depositFor(account, amount);
            return;
        } else {
            rewardToken.depositFor(account, amount);
        }

        assertEq(rewardToken.getLockedAmountsLength(account), 0);
        if (amount != 0) {
            vm.expectEmit(true, false, false, true, address(rewardToken));
            emit ERC20WrapperLocked.LockCreated(account, normalizedTimestamp);
        }
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus.NONE);
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
        uint256 delta,
        uint8 status
    ) external {
        vm.assume(account != address(0) && account != owner && account != address(rewardToken));
        vm.assume(i > 0);
        vm.assume(status != 0 && status < 3);
        delta = bound(delta, 0, 2 days);

        vm.warp(timestamp);
        mint(owner, uint256(amount) * i);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, ERC20WrapperLocked.WhitelistStatus.HIGHER);
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
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(status));
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
        uint8 callerWhitelistStatus,
        uint8 accountWhitelistStatus,
        uint8 receiverWhitelistStatus,
        address caller,
        address account,
        address receiver,
        uint256 amount
    ) external {
        vm.assume(callerWhitelistStatus < 3 && accountWhitelistStatus < 3 && receiverWhitelistStatus < 3);
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
        rewardToken.setWhitelistStatus(caller, ERC20WrapperLocked.WhitelistStatus(callerWhitelistStatus));
        rewardToken.setWhitelistStatus(account, ERC20WrapperLocked.WhitelistStatus(accountWhitelistStatus));
        rewardToken.setWhitelistStatus(receiver, ERC20WrapperLocked.WhitelistStatus(receiverWhitelistStatus));
        vm.stopPrank();

        if (ERC20WrapperLocked.WhitelistStatus(callerWhitelistStatus) == ERC20WrapperLocked.WhitelistStatus.HIGHER) {
            assertEq(erc20Mintable.balanceOf(caller), amount);
            assertEq(erc20Mintable.balanceOf(account), 0);
            vm.prank(caller);
            rewardToken.depositFor(account, amount);
            assertEq(erc20Mintable.balanceOf(caller), 0);
            assertEq(rewardToken.balanceOf(account), amount);

            uint256 snapshot = vm.snapshotState();

            if (ERC20WrapperLocked.WhitelistStatus(accountWhitelistStatus) != ERC20WrapperLocked.WhitelistStatus.NONE) {
                vm.startPrank(account);
                if (
                    ERC20WrapperLocked.WhitelistStatus(accountWhitelistStatus)
                        == ERC20WrapperLocked.WhitelistStatus.HIGHER
                ) {
                    rewardToken.withdrawTo(receiver, amount);
                    assertEq(erc20Mintable.balanceOf(receiver), amount);
                    assertEq(rewardToken.balanceOf(account), 0);
                } else {
                    vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                    rewardToken.withdrawTo(receiver, amount);
                }

                vm.revertToState(snapshot);
                rewardToken.transfer(receiver, amount);
                assertEq(rewardToken.balanceOf(receiver), amount);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(
                    rewardToken.getLockedAmountsLength(receiver),
                    ERC20WrapperLocked.WhitelistStatus(receiverWhitelistStatus)
                        != ERC20WrapperLocked.WhitelistStatus.NONE ? 0 : 1
                );

                vm.revertToState(snapshot);
                rewardToken.approve(receiver, amount);
                vm.stopPrank();

                vm.prank(receiver);
                rewardToken.transferFrom(account, receiver, amount);
                assertEq(rewardToken.balanceOf(receiver), amount);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(
                    rewardToken.getLockedAmountsLength(receiver),
                    ERC20WrapperLocked.WhitelistStatus(receiverWhitelistStatus)
                        != ERC20WrapperLocked.WhitelistStatus.NONE ? 0 : 1
                );
            } else {
                vm.startPrank(account);
                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                rewardToken.withdrawTo(receiver, amount);

                if (
                    ERC20WrapperLocked.WhitelistStatus(receiverWhitelistStatus)
                        != ERC20WrapperLocked.WhitelistStatus.NONE
                ) {
                    assertEq(rewardToken.balanceOf(account), amount);
                    assertEq(rewardToken.balanceOf(receiver), 0);
                    assertEq(rewardToken.getLockedAmountsLength(account), 1);
                    rewardToken.transfer(receiver, amount);
                    assertEq(rewardToken.balanceOf(account), 0);
                    assertEq(rewardToken.balanceOf(receiver), amount);
                    assertEq(rewardToken.getLockedAmountsLength(account), 0);
                } else {
                    vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                    rewardToken.transfer(receiver, amount);
                }

                vm.revertToState(snapshot);
                assertEq(rewardToken.getLockedAmountsLength(account), 1);
                rewardToken.withdrawToByLockTimestamp(receiver, 0, true);
                assertEq(erc20Mintable.balanceOf(receiver), amount / 5);
                assertEq(erc20Mintable.balanceOf(remainderReceiver), amount - amount / 5);
                assertEq(rewardToken.balanceOf(account), 0);
                assertEq(rewardToken.getLockedAmountsLength(account), 0);

                vm.revertToState(snapshot);
                rewardToken.approve(caller, amount);
                vm.stopPrank();
                vm.startPrank(caller);

                if (
                    ERC20WrapperLocked.WhitelistStatus(receiverWhitelistStatus)
                        != ERC20WrapperLocked.WhitelistStatus.NONE
                ) {
                    assertEq(rewardToken.balanceOf(account), amount);
                    assertEq(rewardToken.balanceOf(receiver), 0);
                    assertEq(rewardToken.getLockedAmountsLength(account), 1);
                    rewardToken.transferFrom(account, receiver, amount);
                    assertEq(rewardToken.balanceOf(account), 0);
                    assertEq(rewardToken.balanceOf(receiver), amount);
                    assertEq(rewardToken.getLockedAmountsLength(account), 0);
                } else {
                    vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                    rewardToken.transferFrom(account, receiver, amount);
                }
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
        rewardToken.setWhitelistStatus(owner, ERC20WrapperLocked.WhitelistStatus.HIGHER);
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
        rewardToken.setWhitelistStatus(owner, ERC20WrapperLocked.WhitelistStatus.HIGHER);
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

    function test_transfer() external {
        mint(owner, 1e18);

        vm.startPrank(owner);
        rewardToken.setWhitelistStatus(owner, ERC20WrapperLocked.WhitelistStatus.HIGHER);

        vm.warp(1000);
        rewardToken.depositFor(address(1), 1000);

        vm.warp(1000 + 1 days);
        rewardToken.depositFor(address(1), 1000);

        vm.warp(1000 + 10 days);
        rewardToken.depositFor(address(1), 1000);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(1)), 3000);
        assertEq(rewardToken.getLockedAmountsLength(address(1)), 3);

        vm.prank(address(1));
        vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
        rewardToken.transfer(address(2), 1000);

        vm.prank(owner);
        rewardToken.setWhitelistStatus(address(2), ERC20WrapperLocked.WhitelistStatus.LOWER);
        uint256 snapshot = vm.snapshotState();

        vm.startPrank(address(1));
        rewardToken.transfer(address(2), 1000);
        assertEq(rewardToken.balanceOf(address(1)), 2000);
        assertEq(rewardToken.balanceOf(address(2)), 1000);
        assertEq(rewardToken.getLockedAmountsLength(address(1)), 2);
        assertEq(rewardToken.getLockedAmountsLength(address(2)), 0);

        vm.revertToState(snapshot);
        rewardToken.transfer(address(2), 1500);
        assertEq(rewardToken.balanceOf(address(1)), 1500);
        assertEq(rewardToken.balanceOf(address(2)), 1500);
        assertEq(rewardToken.getLockedAmountsLength(address(1)), 2);
        assertEq(rewardToken.getLockedAmountsLength(address(2)), 0);

        vm.revertToState(snapshot);
        rewardToken.transfer(address(2), 2000);
        assertEq(rewardToken.balanceOf(address(1)), 1000);
        assertEq(rewardToken.balanceOf(address(2)), 2000);
        assertEq(rewardToken.getLockedAmountsLength(address(1)), 1);
        assertEq(rewardToken.getLockedAmountsLength(address(2)), 0);

        vm.revertToState(snapshot);
        rewardToken.transfer(address(2), 3000);
        assertEq(rewardToken.balanceOf(address(1)), 0);
        assertEq(rewardToken.balanceOf(address(2)), 3000);
        assertEq(rewardToken.getLockedAmountsLength(address(1)), 0);
        assertEq(rewardToken.getLockedAmountsLength(address(2)), 0);

        vm.revertToState(snapshot);
        vm.expectRevert();
        rewardToken.transfer(address(2), 3001);
    }
}
