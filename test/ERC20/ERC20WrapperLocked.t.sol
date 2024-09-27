// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Vm, Test} from "forge-std/Test.sol";
import {EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";
import {ERC20Mintable} from "../../script/utils/ScriptUtils.s.sol";
import {ERC20WrapperLocked, EVCUtil, Ownable} from "../../src/ERC20/ERC20WrapperLocked.sol";

contract ERC20WrapperLockedTest is Test {
    address owner = makeAddr("owner");
    EthereumVaultConnector evc;
    ERC20Mintable erc20Mintable;
    ERC20WrapperLocked erc20WrapperLocked;

    function setUp() public {
        evc = new EthereumVaultConnector();
        erc20Mintable = new ERC20Mintable(owner, "ERC20Mintable", "ERC20Mintable", 18);
        erc20WrapperLocked = new ERC20WrapperLocked(
            address(evc), owner, address(erc20Mintable), "ERC20WrapperLocked", "ERC20WrapperLocked"
        );
    }

    function mint(address account, uint256 amount) internal {
        vm.prank(owner);
        erc20Mintable.mint(account, amount);

        vm.prank(account);
        erc20Mintable.approve(address(erc20WrapperLocked), amount);
    }

    function test_setWhitelistStatus(address nonOwner, address account, bool status) external {
        vm.assume(nonOwner != owner && nonOwner != address(evc) && owner != address(evc));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        erc20WrapperLocked.setWhitelistStatus(account, status);

        vm.startPrank(owner);
        bool statusWillChange = status != erc20WrapperLocked.isWhitelisted(account);
        if (statusWillChange) {
            vm.expectEmit(true, false, false, true, address(erc20WrapperLocked));
            emit ERC20WrapperLocked.WhitelistStatus(account, status);
        }
        erc20WrapperLocked.setWhitelistStatus(account, status);
        assertEq(erc20WrapperLocked.isWhitelisted(account), status);
    }

    function test_setWhitelistStatus_lockCreated(address account, uint256 amount, uint256 timestamp) external {
        vm.assume(owner != address(evc));
        vm.assume(account != address(0) && account != owner && account != address(erc20WrapperLocked));

        vm.warp(timestamp);
        mint(owner, amount);
        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);

        vm.startPrank(owner);
        erc20WrapperLocked.setWhitelistStatus(owner, true);
        erc20WrapperLocked.setWhitelistStatus(account, true);
        erc20WrapperLocked.depositFor(account, amount);

        assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 0);
        if (amount != 0) {
            vm.expectEmit(true, true, false, false, address(erc20WrapperLocked));
            emit ERC20WrapperLocked.LockCreated(account, normalizedTimestamp);
        }
        erc20WrapperLocked.setWhitelistStatus(account, false);
        if (amount != 0) {
            assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 1);
            assertEq(erc20WrapperLocked.getLockedAmountsLockTimestamps(account)[0], normalizedTimestamp);
            assertEq(erc20WrapperLocked.getLockedAmountByLockTimestamp(account, normalizedTimestamp), amount);
            (uint256[] memory lockTimestamps, uint256[] memory amounts) = erc20WrapperLocked.getLockedAmounts(account);
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
        vm.assume(account != address(0) && account != owner && account != address(erc20WrapperLocked));
        vm.assume(i > 0);
        delta = bound(delta, 0, 2 days);

        vm.warp(timestamp);
        mint(owner, uint256(amount) * i);

        vm.startPrank(owner);
        erc20WrapperLocked.setWhitelistStatus(owner, true);
        erc20WrapperLocked.depositFor(owner, uint256(amount) * i);

        Vm.Log[] memory logs;
        uint256 previousNormalizedTimestamp = block.timestamp - (block.timestamp % 1 days);
        for (uint256 j = 0; j < i; j++) {
            uint256 previousLockAmount =
                erc20WrapperLocked.getLockedAmountByLockTimestamp(account, previousNormalizedTimestamp);
            uint256 newNormalizedTimestamp = block.timestamp - (block.timestamp % 1 days);

            if (amount != 0 && (j == 0 || newNormalizedTimestamp != previousNormalizedTimestamp)) {
                vm.expectEmit(true, true, false, false, address(erc20WrapperLocked));
                emit ERC20WrapperLocked.LockCreated(account, newNormalizedTimestamp);
            }

            vm.recordLogs();
            erc20WrapperLocked.transfer(account, amount);

            if (amount != 0) {
                if (j == 0 || newNormalizedTimestamp != previousNormalizedTimestamp) {
                    assertEq(erc20WrapperLocked.getLockedAmountByLockTimestamp(account, newNormalizedTimestamp), amount);
                } else {
                    logs = vm.getRecordedLogs();
                    assertEq(logs.length, 1);
                    assertEq(
                        erc20WrapperLocked.getLockedAmountByLockTimestamp(account, newNormalizedTimestamp),
                        previousLockAmount + amount
                    );
                }
            }

            previousNormalizedTimestamp = newNormalizedTimestamp;
            vm.warp(block.timestamp + delta);
        }

        uint256[] memory lockTimestamps1 = erc20WrapperLocked.getLockedAmountsLockTimestamps(account);
        if (amount != 0) {
            (uint256[] memory lockTimestamps2, uint256[] memory amounts) = erc20WrapperLocked.getLockedAmounts(account);

            assertEq(erc20WrapperLocked.getLockedAmountsLength(account), lockTimestamps1.length);
            assertEq(lockTimestamps1.length, lockTimestamps2.length);
            for (uint256 j = 0; j < lockTimestamps1.length; j++) {
                assertEq(lockTimestamps1[j], lockTimestamps2[j]);
                assertEq(amounts[j], erc20WrapperLocked.getLockedAmountByLockTimestamp(account, lockTimestamps1[j]));
            }
        }

        vm.recordLogs();
        erc20WrapperLocked.setWhitelistStatus(account, true);
        logs = vm.getRecordedLogs();

        if (lockTimestamps1.length == 0) {
            assertEq(logs.length, 1);
        } else {
            assertEq(logs.length, lockTimestamps1.length + 1);
            for (uint256 j = 0; j < lockTimestamps1.length; j++) {
                assertEq(logs[j].topics.length, 3);
                assertEq(logs[j].topics[0], keccak256("LockRemoved(address,uint256)"));
                assertEq(logs[j].topics[1], bytes32(uint256(uint160(account))));
                assertEq(logs[j].topics[2], bytes32(lockTimestamps1[j]));
            }
        }
        assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 0);
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
            caller != address(0) && account != address(0) && caller != account && caller != address(erc20WrapperLocked)
                && account != address(erc20WrapperLocked) && caller != address(evc) && account != address(evc)
        );
        vm.assume(receiver != address(0) && receiver != caller && receiver != account && receiver != address(evc));
        vm.assume(amount > 0 && amount < type(uint256).max / 1e4);

        mint(caller, amount);

        vm.startPrank(owner);
        if (isCallerWhitelisted) erc20WrapperLocked.setWhitelistStatus(caller, true);
        if (isAccountWhitelisted) erc20WrapperLocked.setWhitelistStatus(account, true);
        if (isReceiverWhitelisted) erc20WrapperLocked.setWhitelistStatus(receiver, true);
        vm.stopPrank();

        if (isCallerWhitelisted) {
            assertEq(erc20Mintable.balanceOf(caller), amount);
            assertEq(erc20Mintable.balanceOf(account), 0);
            vm.prank(caller);
            erc20WrapperLocked.depositFor(account, amount);
            assertEq(erc20Mintable.balanceOf(caller), 0);
            assertEq(erc20WrapperLocked.balanceOf(account), amount);

            uint256 snapshot = vm.snapshot();

            if (isAccountWhitelisted) {
                vm.startPrank(account);
                erc20WrapperLocked.withdrawTo(receiver, amount);
                assertEq(erc20Mintable.balanceOf(receiver), amount);
                assertEq(erc20WrapperLocked.balanceOf(account), 0);

                vm.revertTo(snapshot);
                erc20WrapperLocked.transfer(receiver, amount);
                assertEq(erc20WrapperLocked.balanceOf(receiver), amount);
                assertEq(erc20WrapperLocked.balanceOf(account), 0);
                assertEq(erc20WrapperLocked.getLockedAmountsLength(receiver), isReceiverWhitelisted ? 0 : 1);

                vm.revertTo(snapshot);
                erc20WrapperLocked.approve(receiver, amount);
                vm.stopPrank();

                vm.prank(receiver);
                erc20WrapperLocked.transferFrom(account, receiver, amount);
                assertEq(erc20WrapperLocked.balanceOf(receiver), amount);
                assertEq(erc20WrapperLocked.balanceOf(account), 0);
                assertEq(erc20WrapperLocked.getLockedAmountsLength(receiver), isReceiverWhitelisted ? 0 : 1);
            } else {
                vm.startPrank(account);
                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                erc20WrapperLocked.withdrawTo(receiver, amount);

                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                erc20WrapperLocked.transfer(receiver, amount);

                vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
                erc20WrapperLocked.withdrawTo(receiver, amount);

                assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 1);
                erc20WrapperLocked.withdrawToByLockTimestamp(receiver, 0);
                assertEq(erc20Mintable.balanceOf(receiver), amount / 5);
                assertEq(erc20Mintable.balanceOf(0x000000000000000000000000000000000000dEaD), amount - amount / 5);
                assertEq(erc20WrapperLocked.balanceOf(account), 0);
                assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 0);
            }
        } else {
            vm.prank(caller);
            vm.expectRevert(abi.encodeWithSelector(EVCUtil.NotAuthorized.selector));
            erc20WrapperLocked.depositFor(account, amount);
        }
    }

    function test_withdrawToByLockTimestamp(
        address account,
        address receiver,
        uint256 amount,
        uint32 timestamp,
        uint256 delta
    ) external {
        vm.assume(
            account != address(0) && account != owner && account != address(erc20WrapperLocked)
                && account != address(evc)
        );
        vm.assume(receiver != address(0) && receiver != account);
        vm.assume(amount < type(uint256).max / 1e4);
        delta = bound(delta, 0, 100 days);

        vm.warp(timestamp);
        mint(owner, amount);

        vm.startPrank(owner);
        erc20WrapperLocked.setWhitelistStatus(owner, true);
        erc20WrapperLocked.depositFor(account, amount);
        vm.stopPrank();

        uint256 normalizedTimestamp = block.timestamp - (block.timestamp % 1 days);
        vm.warp(normalizedTimestamp + delta);
        assertEq(erc20WrapperLocked.getLockedAmountsLength(account), amount != 0 ? 1 : 0);
        assertEq(erc20WrapperLocked.getLockedAmountByLockTimestamp(account, normalizedTimestamp), amount);
        assertEq(erc20WrapperLocked.balanceOf(account), amount);

        vm.startPrank(account);
        erc20WrapperLocked.withdrawToByLockTimestamp(receiver, normalizedTimestamp);
        uint256 expectedAmount;
        if (delta <= 30 days) {
            expectedAmount = amount / 5;
        } else if (delta >= 90 days) {
            expectedAmount = amount;
        } else {
            expectedAmount = ((delta - 30 days) * 0.6e4 / 60 days + 0.2e4) * amount / 1e4;
        }
        assertEq(erc20Mintable.balanceOf(receiver), expectedAmount);
        assertEq(erc20Mintable.balanceOf(0x000000000000000000000000000000000000dEaD), amount - expectedAmount);
        assertEq(erc20WrapperLocked.balanceOf(account), 0);
        assertEq(erc20WrapperLocked.getLockedAmountsLength(account), 0);
    }
}
