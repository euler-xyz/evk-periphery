// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20Wrapper, ERC20, IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {EnumerableMap} from "openzeppelin-contracts/utils/structs/EnumerableMap.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title ERC20WrapperLocked
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A wrapper for locked ERC20 tokens that can be withdrawn as per the lock schedule.
/// @dev Regular wrapping (`depositFor`), unwrapping (`withdrawTo`), and `transfer` are only supported for whitelisted
/// callers. `transferFrom` is only supported for whitelisted `from` addresses. If the account balance is
/// non-whitelisted, their tokens can only be withdrawn as per the lock schedule and the remainder of the amount is
/// transferred to the receiver address configured.
/// @dev The wrapped token is assumed to be well behaved, including not rebasing, not attempting to re-enter this
/// wrapper contract, and not presenting any other weird behavior.
abstract contract ERC20WrapperLocked is EVCUtil, Ownable, ERC20Wrapper {
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using SafeERC20 for IERC20;

    /// @notice The factor used to normalize lock timestamps to daily intervals
    /// @dev This constant is used to round down timestamps to the nearest day when creating locks
    uint256 internal constant LOCK_NORMALIZATION_FACTOR = 1 days;

    /// @notice Scaling factor for percentage calculations
    uint256 internal constant SCALE = 1e18;

    /// @notice Address that will receive the remainder of the tokens after the lock schedule is applied. If zero
    /// address, the remainder of the tokens will be sent to the owner.
    address public remainderReceiver;

    /// @notice Mapping to store whitelist status of addresses
    mapping(address => bool) public isWhitelisted;

    /// @notice Mapping to store locked token amount for each address and normalized lock timestamp
    mapping(address => EnumerableMap.UintToUintMap) internal lockedAmounts;

    /// @notice Emitted when the remainder receiver address is set or changed
    /// @param remainderReceiver The address of the new remainder receiver
    event RemainderReceiverSet(address indexed remainderReceiver);

    /// @notice Emitted when an account's whitelist status changes
    /// @param account The address of the account
    /// @param status The new whitelist status
    event WhitelistStatus(address indexed account, bool status);

    /// @notice Emitted when a new lock is created for an account
    /// @param account The address of the account for which the lock was created
    /// @param lockTimestamp The normalized timestamp of the created lock
    event LockCreated(address indexed account, uint256 lockTimestamp);

    /// @notice Emitted when a lock is removed for an account
    /// @param account The address of the account for which the lock was removed
    /// @param lockTimestamp The normalized timestamp of the removed lock
    event LockRemoved(address indexed account, uint256 lockTimestamp);

    /// @notice Thrown when the remainder loss is not allowed but the calculated remainder amount is non-zero
    error RemainderLossNotAllowed();

    /// @notice Modifier to restrict function access to whitelisted addresses
    /// @param account The address to check for whitelist status
    modifier onlyWhitelisted(address account) {
        if (!isWhitelisted[account]) revert NotAuthorized();
        _;
    }

    /// @notice Constructor for ERC20WrapperLocked
    /// @param _evc Address of the Ethereum Vault Connector
    /// @param _owner Address of the contract owner
    /// @param _remainderReceiver Address that will receive the remainder of the tokens after the lock schedule is
    /// applied. If zero address, the remainder of the tokens will be sent to the owner.
    /// @param _underlying Address of the underlying ERC20 token
    /// @param _name Name of the wrapper token
    /// @param _symbol Symbol of the wrapper token
    constructor(
        address _evc,
        address _owner,
        address _remainderReceiver,
        address _underlying,
        string memory _name,
        string memory _symbol
    ) EVCUtil(_evc) Ownable(_owner) ERC20Wrapper(IERC20(_underlying)) ERC20(_name, _symbol) {
        remainderReceiver = _remainderReceiver;
        emit RemainderReceiverSet(_remainderReceiver);
    }

    /// @notice Sets a new remainder receiver address
    /// @param _remainderReceiver The address of the new remainder receiver. If zero address, the remainder of the
    /// tokens
    function setRemainderReceiver(address _remainderReceiver) public onlyEVCAccountOwner onlyOwner {
        if (remainderReceiver != _remainderReceiver) {
            remainderReceiver = _remainderReceiver;
            emit RemainderReceiverSet(_remainderReceiver);
        }
    }

    /// @notice Sets the whitelist status for an account
    /// @dev If the account is being whitelisted, all the locked amounts are removed resulting in all the tokens being
    /// unlocked. If the account being removed from the whitelist, the current account balance is locked. The side
    /// effect of this behavior is that the owner can modify the lock schedule for users, i.e. by adding and then
    /// removing an account from the whitelist, the owner can reset the unlock schedule for that account. It must be
    /// noted though that the ability to modify whitelist status and its effects on locks is a core feature of this
    /// contract.
    /// @param account The address to set the whitelist status for
    /// @param status The whitelist status to set
    function setWhitelistStatus(address account, bool status) public onlyEVCAccountOwner onlyOwner {
        if (isWhitelisted[account] != status) {
            if (status) {
                EnumerableMap.UintToUintMap storage map = lockedAmounts[account];
                uint256[] memory lockTimestamps = map.keys();
                for (uint256 i = 0; i < lockTimestamps.length; ++i) {
                    map.remove(lockTimestamps[i]);
                    emit LockRemoved(account, lockTimestamps[i]);
                }
            } else {
                uint256 amount = balanceOf(account);
                if (amount != 0) {
                    uint256 normalizedTimestamp = _getNormalizedTimestamp();
                    lockedAmounts[account].set(normalizedTimestamp, amount);
                    emit LockCreated(account, normalizedTimestamp);
                }
            }

            isWhitelisted[account] = status;
            emit WhitelistStatus(account, status);
        }
    }

    /// @notice Deposits tokens for a specified account
    /// @param account The address to deposit tokens for
    /// @param amount The amount of tokens to deposit
    /// @return bool indicating success of the deposit
    function depositFor(address account, uint256 amount)
        public
        virtual
        override
        onlyWhitelisted(_msgSender())
        returns (bool)
    {
        return super.depositFor(account, amount);
    }

    /// @notice Withdraws tokens to a specified account
    /// @param account The address to withdraw tokens to
    /// @param amount The amount of tokens to withdraw
    /// @return bool indicating success of the withdrawal
    function withdrawTo(address account, uint256 amount)
        public
        virtual
        override
        onlyWhitelisted(_msgSender())
        returns (bool)
    {
        return super.withdrawTo(account, amount);
    }

    /// @notice Transfers tokens to a specified address
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return bool indicating success of the transfer
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        onlyWhitelisted(_msgSender())
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /// @notice Transfers tokens from one address to another
    /// @param from The address to transfer tokens from
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return bool indicating success of the transfer
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        onlyWhitelisted(from)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /// @notice Withdraws tokens to a specified account based on a specific normalized lock timestamp as per the lock
    /// schedule. The remainder of the tokens are transferred to the receiver address configured.
    /// @param account The address to receive the withdrawn tokens
    /// @param lockTimestamp The normalized lock timestamp to withdraw tokens for
    /// @param allowRemainderLoss If true, is it allowed for the remainder of the tokens to be transferred to the
    /// receiver address configured as per the lock schedule. If false and the calculated remainder amount is non-zero,
    /// the withdrawal will revert.
    /// @return bool indicating success of the withdrawal
    function withdrawToByLockTimestamp(address account, uint256 lockTimestamp, bool allowRemainderLoss)
        public
        virtual
        returns (bool)
    {
        uint256[] memory lockTimestamps = new uint256[](1);
        lockTimestamps[0] = lockTimestamp;
        return withdrawToByLockTimestamps(account, lockTimestamps, allowRemainderLoss);
    }

    /// @notice Withdraws tokens to a specified account based on multiple normalized lock timestamps as per the lock
    /// schedule.
    /// The remainder of the tokens are transferred to the receiver address configured.
    /// @param account The address to receive the withdrawn tokens
    /// @param lockTimestamps An array of normalized lock timestamps to withdraw tokens for
    /// @param allowRemainderLoss If true, is it allowed for the remainder of the tokens to be transferred to the
    /// receiver address configured as per the lock schedule. If false and the calculated remainder amount is non-zero,
    /// the withdrawal will revert.
    /// @return bool indicating success of the withdrawal
    function withdrawToByLockTimestamps(address account, uint256[] memory lockTimestamps, bool allowRemainderLoss)
        public
        virtual
        returns (bool)
    {
        IERC20 asset = underlying();
        address sender = _msgSender();

        uint256 totalAccountAmount;
        uint256 totalRemainderAmount;
        for (uint256 i = 0; i < lockTimestamps.length; ++i) {
            uint256 lockTimestamp = lockTimestamps[i];
            (uint256 accountAmount, uint256 remainderAmount) = getWithdrawAmountsByLockTimestamp(sender, lockTimestamp);

            if (lockedAmounts[sender].remove(lockTimestamp)) {
                emit LockRemoved(sender, lockTimestamp);
            }

            totalAccountAmount += accountAmount;
            totalRemainderAmount += remainderAmount;
        }

        _burn(sender, totalAccountAmount + totalRemainderAmount);
        asset.safeTransfer(account, totalAccountAmount);

        if (totalRemainderAmount != 0) {
            if (!allowRemainderLoss) revert RemainderLossNotAllowed();

            address receiver = remainderReceiver;
            asset.safeTransfer(receiver == address(0) ? owner() : receiver, totalRemainderAmount);
        }

        return true;
    }

    /// @notice Calculates the withdraw amounts for a given account and normalized lock timestamp
    /// @param account The address of the account to check
    /// @param lockTimestamp The normalized lock timestamp to check for withdraw amounts
    /// @return accountAmount The amount that can be unlocked and sent to the account
    /// @return remainderAmount The amount that will be transferred to the configured receiver address
    function getWithdrawAmountsByLockTimestamp(address account, uint256 lockTimestamp)
        public
        view
        virtual
        returns (uint256, uint256)
    {
        (, uint256 amount) = lockedAmounts[account].tryGet(lockTimestamp);
        uint256 accountShare = _calculateUnlockShare(lockTimestamp);
        uint256 accountAmount = amount * accountShare / SCALE;
        uint256 remainderAmount = amount - accountAmount;
        return (accountAmount, remainderAmount);
    }

    /// @notice Gets the number of locked amount entries for an account
    /// @param account The address to check
    /// @return The number of locked amount entries
    function getLockedAmountsLength(address account) public view returns (uint256) {
        return lockedAmounts[account].length();
    }

    /// @notice Gets all the normalized lock timestamps of locked amounts for an account
    /// @param account The address to check
    /// @return An array of normalized lock timestamps
    function getLockedAmountsLockTimestamps(address account) public view returns (uint256[] memory) {
        return lockedAmounts[account].keys();
    }

    /// @notice Gets the locked amount for an account at a specific normalized lock timestamp
    /// @param account The address to check
    /// @param lockTimestamp The normalized lock timestamp to check
    /// @return The locked amount at the specified timestamp
    function getLockedAmountByLockTimestamp(address account, uint256 lockTimestamp) public view returns (uint256) {
        (, uint256 amount) = lockedAmounts[account].tryGet(lockTimestamp);
        return amount;
    }

    /// @notice Gets all locked amounts for an account
    /// @param account The address to check
    /// @return Two arrays: normalized lock timestamps and corresponding amounts
    function getLockedAmounts(address account) public view returns (uint256[] memory, uint256[] memory) {
        EnumerableMap.UintToUintMap storage map = lockedAmounts[account];
        uint256[] memory lockTimestamp = map.keys();
        uint256[] memory amounts = new uint256[](lockTimestamp.length);

        for (uint256 i = 0; i < lockTimestamp.length; i++) {
            amounts[i] = map.get(lockTimestamp[i]);
        }

        return (lockTimestamp, amounts);
    }

    /// @notice Internal function to update balances
    /// @dev Regular ERC20 transfers are only supported for whitelisted addresses. When the amount is transferred to a
    /// non-whitelisted address, the amount is locked as per the lock schedule.
    /// @param from Address to transfer from
    /// @param to Address to transfer to
    /// @param amount Amount to transfer
    function _update(address from, address to, uint256 amount) internal virtual override {
        if (to != address(0) && amount != 0 && !isWhitelisted[to]) {
            EnumerableMap.UintToUintMap storage map = lockedAmounts[to];
            uint256 normalizedTimestamp = _getNormalizedTimestamp();
            (, uint256 currentAmount) = map.tryGet(normalizedTimestamp);

            if (map.set(normalizedTimestamp, currentAmount + amount)) {
                emit LockCreated(to, normalizedTimestamp);
            }
        }

        super._update(from, to, amount);
    }

    /// @notice Calculates the share of tokens that can be unlocked based on the lock timestamp
    /// @dev This function should be overridden by the child contract to implement the specific unlock schedule
    /// @param lockTimestamp The timestamp when the tokens were locked
    /// @return The share of tokens that can be freely unlocked (in basis points)
    function _calculateUnlockShare(uint256 lockTimestamp) internal view virtual returns (uint256);

    /// @notice Internal function to get the normalized timestamp
    /// @return The normalized timestamp (rounded down to the nearest day)
    function _getNormalizedTimestamp() internal view virtual returns (uint256) {
        return block.timestamp - (block.timestamp % LOCK_NORMALIZATION_FACTOR);
    }

    /// @notice Internal function to get the authenticated message sender
    /// @return The address of the authenticated message sender
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}