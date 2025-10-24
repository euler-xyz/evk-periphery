// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {ERC4626EVC, ERC4626EVCCollateral} from "../implementation/ERC4626EVCCollateral.sol";
import {IVault} from "evc/interfaces/IVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title ERC4626EVCCollateralCappedPausable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation that allows setting a supply cap and pausing the
/// contract.
abstract contract ERC4626EVCCollateralCappedPausable is ERC4626EVCCollateral {
    using AmountCapLib for AmountCap;

    /// @notice Unlocked state.
    uint8 internal constant UNLOCKED = 1;

    /// @notice Locked state.
    uint8 internal constant LOCKED = 2;

    /// @notice The address of the governor admin.
    address public governorAdmin;

    /// @notice Lock for reentrancy.
    uint8 internal _reentrancyLock;

    /// @notice Lock for pause.
    uint8 internal _pauseLock;

    /// @notice Lock for snapshot.
    uint8 internal _snapshotLock;

    /// @notice The supply cap.
    AmountCap internal _supplyCap;

    /// @notice The snapshot of the total assets.
    uint256 internal _snapshotTotalAssets;

    /// @notice Emitted when the governor admin is set.
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);

    /// @notice Emitted when the contract is paused.
    event GovPaused();

    /// @notice Emitted when the contract is unpaused.
    event GovUnpaused();

    /// @notice Set new supply cap
    /// @param newSupplyCap New supply cap in AmountCap format
    event GovSetSupplyCap(uint16 newSupplyCap);

    /// @notice Error thrown when a reentrancy is detected.
    error Reentrancy();

    /// @notice Error thrown when the contract is paused.
    error Paused();

    /// @notice Error thrown when the supply cap is invalid.
    error BadSupplyCap();

    /// @notice Error thrown when the supply cap is exceeded.
    error SupplyCapExceeded();

    /// @notice Modifier to prevent reentrancy.
    modifier nonReentrant() virtual {
        if (_reentrancyLock == LOCKED) revert Reentrancy();
        _reentrancyLock = LOCKED;
        _;
        _reentrancyLock = UNLOCKED;
    }

    /// @notice Modifier to restrict access to the contract when it is paused.
    modifier whenNotPaused() virtual {
        if (_pauseLock == LOCKED) revert Paused();
        _pauseLock = LOCKED;
        _;
        _pauseLock = UNLOCKED;
    }

    /// @notice Modifier to restrict access to the governor admin.
    modifier governorOnly() virtual {
        if (governorAdmin != _msgSender()) revert NotAuthorized();
        _;
    }

    /// @notice Modifier that takes a snapshot before executing the function body.
    modifier takeSnapshot() virtual {
        _takeSnapshot();
        _;
    }

    /// @dev Initializes the contract.
    /// @param admin The address of the governor admin.
    constructor(address admin) {
        _reentrancyLock = UNLOCKED;
        _pauseLock = UNLOCKED;
        _snapshotLock = UNLOCKED;
        governorAdmin = admin;
    }

    /// @notice Sets a new governor admin for the vault.
    /// @param newGovernorAdmin The address of the new governor admin.
    function setGovernorAdmin(address newGovernorAdmin) public virtual onlyEVCAccountOwner governorOnly {
        if (newGovernorAdmin == address(0)) revert InvalidAddress();
        if (newGovernorAdmin == governorAdmin) return;
        governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @notice Pauses the contract.
    function pause() public virtual onlyEVCAccountOwner governorOnly {
        if (_pauseLock == LOCKED) return;
        _pauseLock = LOCKED;
        emit GovPaused();
    }

    /// @notice Unpauses the contract.
    function unpause() public virtual onlyEVCAccountOwner governorOnly {
        if (_pauseLock == UNLOCKED) return;
        _pauseLock = UNLOCKED;
        emit GovUnpaused();
    }

    /// @notice Sets the supply cap for the vault.
    /// @param cap The new supply cap value, encoded as a 16-bit AmountCap.
    function setSupplyCap(uint16 cap) public virtual onlyEVCAccountOwner governorOnly {
        AmountCap _cap = AmountCap.wrap(cap);

        // The raw uint16 cap amount == 0 is a special value. See comments in AmountCap.sol
        // Max total assets is a sum of max pool size and max total debt, both Assets type
        if (cap != 0 && _cap.resolve() > 2 * MAX_SANE_AMOUNT) revert BadSupplyCap();

        _supplyCap = _cap;

        emit GovSetSupplyCap(cap);
    }

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return result A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        returns (bool result)
    {
        result = super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return result A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        returns (bool result)
    {
        result = super.transferFrom(from, to, amount);
    }

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        takeSnapshot
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
        evc.requireVaultStatusCheck();
    }

    /// @notice Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        takeSnapshot
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
        evc.requireVaultStatusCheck();
    }

    /// @notice Withdraws a certain amount of assets for a receiver.
    /// @param assets The assets to withdraw.
    /// @param receiver The receiver of the withdrawal.
    /// @param owner The owner of the assets.
    /// @return shares The shares equivalent to the withdrawn assets.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        takeSnapshot
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner);
    }

    /// @notice Redeems a certain amount of shares for a receiver.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        whenNotPaused
        takeSnapshot
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner);
    }

    /// @notice Checks the status of the vault and validates supply cap constraints.
    /// @return magicValue The selector of checkVaultStatus if the vault is in a valid state.
    function checkVaultStatus() external virtual onlyEVCWithChecksInProgress returns (bytes4 magicValue) {
        if (_snapshotLock == LOCKED) {
            uint256 finalTotalAssets = totalAssets();

            if (finalTotalAssets > _supplyCap.resolve() && finalTotalAssets > _snapshotTotalAssets) {
                revert SupplyCapExceeded();
            }

            _snapshotLock = UNLOCKED;
        }

        return IVault.checkVaultStatus.selector;
    }

    /// @notice Checks whether the contract is paused.
    /// @return True if the contract is paused, false otherwise.
    function isPaused() public view virtual returns (bool) {
        return _pauseLock == LOCKED;
    }

    /// @notice Returns the raw supply cap value as a uint16.
    /// @return The raw supply cap in AmountCap format.
    function supplyCap() public view virtual returns (uint16) {
        return _supplyCap.toRawUint16();
    }

    /// @notice Returns the resolved supply cap as a uint256.
    /// @return The resolved supply cap, or type(uint256).max if no cap is set.
    function supplyCapResolved() public view virtual returns (uint256) {
        return _supplyCap.resolve();
    }

    /// @notice Takes a snapshot of the current total assets if not locked.
    function _takeSnapshot() internal virtual {
        if (_snapshotLock == LOCKED || _supplyCap.resolve() == type(uint256).max) return;

        _updateCache();
        _snapshotLock = LOCKED;
        _snapshotTotalAssets = totalAssets();
    }

    /// @notice Updates the cache with any necessary changes, i.e. interest accrual that may affect the snapshot.
    function _updateCache() internal virtual;
}
