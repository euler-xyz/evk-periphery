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
/// @dev Regular wrapping (`depositFor`), unwrapping (`withdrawTo`) are only supported for whitelisted callers with
/// an ADMIN whitelist status. Regular ERC20 `transfer` and `transferFrom` are only supported between two accounts that
/// are not subject to locking. Under other circumstances, conditions apply; look at the `_update` function. If the
/// account is non-whitelisted, their tokens can only be withdrawn as per the lock schedule and the remainder of the
/// amount is transferred to the receiver address configured. If the account has a whitelist status other than ADMIN,
/// their tokens cannot be unwrapped by them, but in order to be unwrapped, they can only be transferred to the account
/// that is non-whitelisted and become a subject to the locking schedule or transferred to the account with an ADMIN
/// whitelist status. A whitelisted account can always degrade their whitelist status and become a subject to the
/// locking schedule.
/// @dev Avoid giving an ADMIN whitelist status to untrusted addresses. They can be used by non-whitelisted accounts and
/// accounts with the other whitelist statuses to avoid the lock schedule.
/// @dev Avoid giving approvals to untrusted spenders. If approved by both a whitelisted account and a non-whitelisted
/// account, they can reset the non-whitelisted account's lock schedule.
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

    /// @notice Constant representing no whitelist status
    uint256 public constant WHITELIST_STATUS_NONE = 0;

    /// @notice Constant representing admin whitelist status
    uint256 public constant WHITELIST_STATUS_ADMIN = 1;

    /// @notice Constant representing distributor whitelist status
    uint256 public constant WHITELIST_STATUS_DISTRIBUTOR = 2;

    /// @notice Constant representing distributor locked whitelist status
    uint256 public constant WHITELIST_STATUS_DISTRIBUTOR_LOCKED = 3;

    /// @notice Maximum whitelist status value
    uint256 public constant WHITELIST_STATUS_MAX = 4;

    /// @notice Address that will receive the remainder of the tokens after the lock schedule is applied. If zero
    /// address, the remainder of the tokens will be sent to the owner.
    address public remainderReceiver;

    /// @notice Mapping to store whitelist status of an addresses
    mapping(address => uint256) public whitelistStatus;

    /// @notice Mapping to store locked token amount for each address and normalized lock timestamp
    mapping(address => EnumerableMap.UintToUintMap) internal lockedAmounts;

    /// @notice Emitted when the remainder receiver address is set or changed
    /// @param remainderReceiver The address of the new remainder receiver
    event RemainderReceiverSet(address indexed remainderReceiver);

    /// @notice Emitted when an account's whitelist status changes
    /// @param account The address of the account
    /// @param status The new whitelist status
    event WhitelistStatusSet(address indexed account, uint256 status);

    /// @notice Emitted when a new lock is created for an account
    /// @param account The address of the account for which the lock was created
    /// @param lockTimestamp The normalized timestamp of the created lock
    event LockCreated(address indexed account, uint256 lockTimestamp);

    /// @notice Emitted when a lock is removed for an account
    /// @param account The address of the account for which the lock was removed
    /// @param lockTimestamp The normalized timestamp of the removed lock
    event LockRemoved(address indexed account, uint256 lockTimestamp);

    /// @notice Error thrown when an invalid whitelist status is provided
    error InvalidWhitelistStatus();

    /// @notice Thrown when the remainder loss is not allowed but the calculated remainder amount is non-zero
    error RemainderLossNotAllowed();

    /// @notice Modifier to restrict function access to the whitelisted addresses
    /// @param account The address to check for whitelist status
    modifier onlyWhitelisted(address account) {
        if (whitelistStatus[account] == WHITELIST_STATUS_NONE) revert NotAuthorized();
        _;
    }

    /// @notice Modifier to restrict function access to the whitelisted ADMIN addresses
    /// @param account The address to check for whitelist status
    modifier onlyWhitelistedAdmin(address account) {
        if (whitelistStatus[account] != WHITELIST_STATUS_ADMIN) revert NotAuthorized();
        _;
    }

    /// @notice Modifier to restrict function access to non-whitelisted addresses
    /// @param account The address to check for whitelist status
    modifier onlyNonWhitelisted(address account) {
        if (whitelistStatus[account] != WHITELIST_STATUS_NONE) revert NotAuthorized();
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

    /// @notice Disables the ability to renounce ownership of the contract
    function renounceOwnership() public pure override {
        revert NotAuthorized();
    }

    /// @notice Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current
    /// owner.
    /// @param newOwner The address of the new owner
    function transferOwnership(address newOwner) public virtual override onlyEVCAccountOwner {
        super.transferOwnership(newOwner);
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

    /// @notice Sets the whitelist status for a specified account
    /// @param account The address to set the whitelist status for
    /// @param status The new whitelist status to set
    function setWhitelistStatus(address account, uint256 status) public onlyEVCAccountOwner onlyOwner {
        if (whitelistStatus[account] != status) _setWhitelistStatus(account, status);
    }

    /// @notice Allows a whitelisted account to degrade its own whitelist status
    /// @param status The new whitelist status to set
    function setWhitelistStatus(uint256 status) public onlyWhitelisted(_msgSender()) {
        address account = _msgSender();
        uint256 currentStatus = whitelistStatus[account];
        if (currentStatus != status) {
            if (currentStatus == WHITELIST_STATUS_ADMIN || _isSubjectToLock(status)) {
                _setWhitelistStatus(account, status);
            } else {
                revert NotAuthorized();
            }
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
        onlyWhitelistedAdmin(_msgSender())
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
        onlyWhitelistedAdmin(_msgSender())
        returns (bool)
    {
        return super.withdrawTo(account, amount);
    }

    /// @notice Transfers tokens to a specified address
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return bool indicating success of the transfer
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return super.transfer(to, amount);
    }

    /// @notice Transfers tokens from one address to another
    /// @param from The address to transfer tokens from
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return bool indicating success of the transfer
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
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
    /// schedule. The remainder of the tokens are transferred to the receiver address configured.
    /// @param account The address to receive the withdrawn tokens
    /// @param lockTimestamps An array of normalized lock timestamps to withdraw tokens for
    /// @param allowRemainderLoss If true, is it allowed for the remainder of the tokens to be transferred to the
    /// receiver address configured as per the lock schedule. If false and the calculated remainder amount is non-zero,
    /// the withdrawal will revert.
    /// @return bool indicating success of the withdrawal
    function withdrawToByLockTimestamps(address account, uint256[] memory lockTimestamps, bool allowRemainderLoss)
        public
        virtual
        onlyNonWhitelisted(_msgSender())
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
        uint256[] memory lockTimestamps = map.keys();
        uint256[] memory amounts = new uint256[](lockTimestamps.length);

        for (uint256 i = 0; i < lockTimestamps.length; i++) {
            amounts[i] = map.get(lockTimestamps[i]);
        }

        return (lockTimestamps, amounts);
    }

    /// @notice Internal function to update balances
    /// @dev Regular ERC20 transfers are only supported between two addresses that are not subject to locking. When the
    /// amount is transferred from an address that is subject to locking to an address that is not subject to locking,
    /// the locked amount entries get subsequently removed starting from the first lock, up to the point when the whole
    /// requested amount is transferred freely. When the amount is transferred from an address that is not subject to
    /// locking to an address that is subject to locking, the amount is locked as per the lock schedule. Transfers from
    /// an address that is subject to locking to another address that is subject to locking are only supported if they
    /// originate from a DISTRIBUTOR_LOCKED address and will revert otherwise.
    /// @param from Address to transfer from
    /// @param to Address to transfer to
    /// @param amount Amount to transfer
    function _update(address from, address to, uint256 amount) internal virtual override {
        if (amount != 0) {
            uint256 fromStatus = whitelistStatus[from];
            bool fromIsSubjectToLock = _isSubjectToLock(fromStatus);
            bool toIsSubjectToLock = _isSubjectToLock(whitelistStatus[to]);

            if ((from == address(0) || !fromIsSubjectToLock) && to != address(0) && toIsSubjectToLock) {
                // Covers minting and transfers from non-subject to subject to locking
                EnumerableMap.UintToUintMap storage map = lockedAmounts[to];
                uint256 normalizedTimestamp = _getNormalizedTimestamp();
                (, uint256 currentAmount) = map.tryGet(normalizedTimestamp);

                if (map.set(normalizedTimestamp, currentAmount + amount)) {
                    emit LockCreated(to, normalizedTimestamp);
                }
            } else if (fromIsSubjectToLock && !toIsSubjectToLock) {
                // Covers transfers from subject to non-subject to locking
                EnumerableMap.UintToUintMap storage map = lockedAmounts[from];
                uint256[] memory lockTimestamps = map.keys();
                uint256 unlockedAmount;

                for (uint256 i = 0; i < lockTimestamps.length; ++i) {
                    uint256 lockTimestamp = lockTimestamps[i];
                    uint256 currentAmount = map.get(lockTimestamp);

                    if (unlockedAmount + currentAmount > amount) {
                        uint256 releasedAmount = amount - unlockedAmount;
                        map.set(lockTimestamp, currentAmount - releasedAmount);
                        currentAmount = releasedAmount;
                    } else {
                        map.remove(lockTimestamp);
                        emit LockRemoved(from, lockTimestamp);
                    }

                    unlockedAmount += currentAmount;

                    if (unlockedAmount >= amount) break;
                }
            } else if (from != address(0) && fromIsSubjectToLock && to != address(0) && toIsSubjectToLock) {
                // Covers transfers from subject to subject to locking. Such transfers are only allowed from
                // DISTRIBUTOR_LOCKED addresses.
                if (fromStatus == WHITELIST_STATUS_DISTRIBUTOR_LOCKED) {
                    EnumerableMap.UintToUintMap storage fromMap = lockedAmounts[from];
                    EnumerableMap.UintToUintMap storage toMap = lockedAmounts[to];
                    uint256[] memory fromLockTimestamps = fromMap.keys();
                    uint256 movedAmount;

                    for (uint256 i = 0; i < fromLockTimestamps.length; ++i) {
                        uint256 lockTimestamp = fromLockTimestamps[i];
                        uint256 fromCurrentAmount = fromMap.get(lockTimestamp);
                        (, uint256 toCurrentAmount) = toMap.tryGet(lockTimestamp);

                        if (movedAmount + fromCurrentAmount > amount) {
                            uint256 releasedAmount = amount - movedAmount;
                            fromMap.set(lockTimestamp, fromCurrentAmount - releasedAmount);
                            fromCurrentAmount = releasedAmount;
                        } else {
                            fromMap.remove(lockTimestamp);
                            emit LockRemoved(from, lockTimestamp);
                        }

                        if (toMap.set(lockTimestamp, toCurrentAmount + fromCurrentAmount)) {
                            emit LockCreated(to, lockTimestamp);
                        }

                        movedAmount += fromCurrentAmount;

                        if (movedAmount >= amount) break;
                    }
                } else {
                    revert NotAuthorized();
                }
            }
        }

        // For burning and transfers from non-subject to non-subject to locking, no special handling needs to be done.
        // `_setWhitelistStatus` ensures that only subject to locking accounts can have locked amounts
        super._update(from, to, amount);
    }

    /// @notice Sets the whitelist status for an account
    /// @dev If the account will not be subject to locking, all locked amounts are removed, resulting in all tokens
    /// being unlocked. If the account will be subject to locking, the current account balance is locked. A side effect
    /// of this behavior is that the owner (and by extension, approved token spenders) can modify the lock schedule for
    /// users. For example, by unmaking and then making the account subject to locking, or by transferring tokens from
    /// an account that is subject to locking to an account that is not subject to locking, the owner and approved token
    /// spenders can reset the unlock schedule for that account. It should be noted that the ability to modify whitelist
    /// status and its effects on locks is a core feature of this contract. On the other hand, regular users must be
    /// vigilant about which addresses they approve to spend their locked tokens which is not unlike other ERC20
    /// approvals.
    /// @param account The address to set the whitelist status for
    /// @param status The whitelist status to set
    function _setWhitelistStatus(address account, uint256 status) internal {
        if (status >= WHITELIST_STATUS_MAX) revert InvalidWhitelistStatus();

        bool isSubjectToLock = _isSubjectToLock(status);
        EnumerableMap.UintToUintMap storage map = lockedAmounts[account];
        uint256[] memory lockTimestamps = map.keys();

        if (isSubjectToLock && lockTimestamps.length == 0) {
            uint256 amount = balanceOf(account);
            if (amount != 0) {
                uint256 normalizedTimestamp = _getNormalizedTimestamp();
                lockedAmounts[account].set(normalizedTimestamp, amount);
                emit LockCreated(account, normalizedTimestamp);
            }
        } else if (!isSubjectToLock) {
            for (uint256 i = 0; i < lockTimestamps.length; ++i) {
                map.remove(lockTimestamps[i]);
                emit LockRemoved(account, lockTimestamps[i]);
            }
        }

        whitelistStatus[account] = status;
        emit WhitelistStatusSet(account, status);
    }

    /// @notice Checks if a whitelist status indicates that an account's tokens are subject to locking
    /// @dev Returns true if the whitelist status is NONE or DISTRIBUTOR_LOCKED
    /// @param status The whitelist status to check
    /// @return True if the account's tokens are subject to locking, false otherwise
    function _isSubjectToLock(uint256 status) internal pure returns (bool) {
        return status == WHITELIST_STATUS_NONE || status == WHITELIST_STATUS_DISTRIBUTOR_LOCKED;
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
