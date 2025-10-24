// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {ERC4626EVC, ERC4626EVCCollateral} from "../implementation/ERC4626EVCCollateral.sol";
import {IVault} from "evc/interfaces/IVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title ERC4626EVCCollateralCapped
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation that allows setting a supply cap.
abstract contract ERC4626EVCCollateralCapped is ERC4626EVCCollateral {
    using AmountCapLib for AmountCap;

    /// @notice Bitmap bit for initialization status.
    uint16 internal constant INITIALIZATION_BIT = 1 << 0;

    /// @notice Bitmap bit for reentrancy status.
    uint16 internal constant REENTRANCY_BIT = 1 << 1;

    /// @notice Bitmap bit for snapshot lock status.
    uint16 internal constant SNAPSHOT_BIT = 1 << 2;

    /// @notice General purpose bitmap for state flags.
    uint16 internal _stateBitmap;

    /// @notice The supply cap.
    AmountCap internal _supplyCap;

    /// @notice The address of the governor admin.
    address public governorAdmin;

    /// @notice The snapshot of the total assets.
    uint256 internal _snapshotTotalAssets;

    /// @notice Emitted when the governor admin is set.
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);

    /// @notice Set new supply cap
    /// @param newSupplyCap New supply cap in AmountCap format
    event GovSetSupplyCap(uint16 newSupplyCap);

    /// @notice Error thrown when a reentrancy is detected.
    error Reentrancy();

    /// @notice Error thrown when the supply cap is invalid.
    error BadSupplyCap();

    /// @notice Error thrown when the supply cap is exceeded.
    error SupplyCapExceeded();

    /// @notice Modifier to prevent reentrancy.
    modifier nonReentrant() {
        uint16 bitmap = _stateBitmap;
        if (_isBitSet(bitmap, REENTRANCY_BIT)) revert Reentrancy();
        _stateBitmap = _setBit(bitmap, REENTRANCY_BIT);
        _;
        _stateBitmap = _clearBit(_stateBitmap, REENTRANCY_BIT);
    }

    /// @notice Modifier to restrict access to the governor admin.
    modifier governorOnly() {
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
        _stateBitmap = _setBit(0, INITIALIZATION_BIT);
        governorAdmin = admin;
    }

    /// @notice Sets a new governor admin for the vault.
    /// @param newGovernorAdmin The address of the new governor admin.
    function setGovernorAdmin(address newGovernorAdmin) public onlyEVCAccountOwner governorOnly {
        if (newGovernorAdmin == address(0)) revert InvalidAddress();
        if (newGovernorAdmin == governorAdmin) return;
        governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @notice Sets the supply cap for the vault.
    /// @param cap The new supply cap value, encoded as a 16-bit AmountCap.
    function setSupplyCap(uint16 cap) public onlyEVCAccountOwner governorOnly {
        AmountCap _cap = AmountCap.wrap(cap);

        // The raw uint16 cap amount == 0 is a special value. See comments in AmountCap.sol
        // Max total assets is a sum of max pool size and max total debt, both Assets type
        if (cap != 0 && _cap.resolve() > 2 * MAX_SANE_AMOUNT) revert BadSupplyCap();

        _supplyCap = _cap;

        emit GovSetSupplyCap(cap);
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
        takeSnapshot
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner);
    }

    /// @notice Checks the status of the vault and validates supply cap constraints.
    /// @return magicValue The selector of checkVaultStatus if the vault is in a valid state.
    function checkVaultStatus() external virtual onlyEVCWithChecksInProgress returns (bytes4 magicValue) {
        uint16 bitmap = _stateBitmap;
        if (_isBitSet(bitmap, SNAPSHOT_BIT)) {
            uint256 finalTotalAssets = totalAssets();

            if (finalTotalAssets > _supplyCap.resolve() && finalTotalAssets > _snapshotTotalAssets) {
                revert SupplyCapExceeded();
            }

            _stateBitmap = _clearBit(bitmap, SNAPSHOT_BIT);
        }

        return IVault.checkVaultStatus.selector;
    }

    /// @notice Returns the raw supply cap value as a uint16.
    /// @return The raw supply cap in AmountCap format.
    function supplyCap() public view returns (uint16) {
        return _supplyCap.toRawUint16();
    }

    /// @notice Returns the resolved supply cap as a uint256.
    /// @return The resolved supply cap, or type(uint256).max if no cap is set.
    function supplyCapResolved() public view returns (uint256) {
        return _supplyCap.resolve();
    }

    /// @notice Checks if a specific bit is set in a bitmap.
    /// @param bitmap The bitmap to check.
    /// @param bit The bit to check for.
    /// @return True if the bit is set, false otherwise.
    function _isBitSet(uint16 bitmap, uint16 bit) internal pure returns (bool) {
        return (bitmap & bit) != 0;
    }

    /// @notice Sets a specific bit in a bitmap.
    /// @param bitmap The bitmap to modify.
    /// @param bit The bit to set.
    /// @return The new bitmap with the bit set.
    function _setBit(uint16 bitmap, uint16 bit) internal pure returns (uint16) {
        return bitmap | bit;
    }

    /// @notice Clears a specific bit in a bitmap.
    /// @param bitmap The bitmap to modify.
    /// @param bit The bit to clear.
    /// @return The new bitmap with the bit cleared.
    function _clearBit(uint16 bitmap, uint16 bit) internal pure returns (uint16) {
        return bitmap & ~bit;
    }

    /// @notice Takes a snapshot of the current total assets if not locked.
    function _takeSnapshot() internal virtual {
        if (_isBitSet(_stateBitmap, SNAPSHOT_BIT) || _supplyCap.resolve() == type(uint256).max) return;

        _updateCache();
        _stateBitmap = _setBit(_stateBitmap, SNAPSHOT_BIT);
        _snapshotTotalAssets = totalAssets();
    }

    /// @notice Updates the cache with any necessary changes, i.e. interest accrual that may affect the snapshot.
    function _updateCache() internal virtual;
}
