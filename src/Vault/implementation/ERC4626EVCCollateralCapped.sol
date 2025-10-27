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

    /// @notice Reentrancy feature index.
    uint8 internal constant REENTRANCY = 0;

    /// @notice Snapshot feature index.
    uint8 internal constant SNAPSHOT = 1;

    /// @notice The address of the governor admin.
    address public governorAdmin;

    /// @notice General purpose bitmap for state features.
    uint16 private _stateBitmap;

    /// @notice The supply cap.
    AmountCap internal _supplyCap;

    /// @notice The snapshot of the total assets.
    uint112 internal _snapshotTotalAssets;

    /// @notice Emitted when the governor admin is set.
    event GovSetGovernorAdmin(address indexed newGovernorAdmin);

    /// @notice Set new supply cap
    /// @param newSupplyCap New supply cap in AmountCap format
    event GovSetSupplyCap(uint16 newSupplyCap);

    /// @notice Error thrown when the feature is already initialized.
    error AlreadyInitialized();

    /// @notice Error thrown when a reentrancy is detected.
    error Reentrancy();

    /// @notice Error thrown when the supply cap is invalid.
    error BadSupplyCap();

    /// @notice Error thrown when the supply cap is exceeded.
    error SupplyCapExceeded();

    /// @notice Modifier to prevent reentrancy.
    modifier nonReentrant() {
        if (_isEnabled(REENTRANCY)) revert Reentrancy();
        _enableFeature(REENTRANCY);
        _;
        _disableFeature(REENTRANCY);
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
        uint8 MAX_FEATURE_INDEX = 15;
        _initializeFeature(MAX_FEATURE_INDEX);
        _initializeFeature(REENTRANCY);
        _initializeFeature(SNAPSHOT);
        governorAdmin = admin;
    }

    /// @notice Sets a new governor admin for the vault.
    /// @param newGovernorAdmin The address of the new governor admin.
    function setGovernorAdmin(address newGovernorAdmin) public onlyEVCAccountOwner governorOnly {
        if (newGovernorAdmin == governorAdmin) return;
        governorAdmin = newGovernorAdmin;
        emit GovSetGovernorAdmin(newGovernorAdmin);
    }

    /// @notice Sets the supply cap for the vault.
    /// @param cap The new supply cap value, encoded as a 16-bit AmountCap.
    function setSupplyCap(uint16 cap) public onlyEVCAccountOwner governorOnly {
        AmountCap _cap = AmountCap.wrap(cap);

        // The raw uint16 cap amount == 0 is a special value. See comments in AmountCap.sol
        if (cap != 0 && _cap.resolve() > MAX_SANE_AMOUNT) revert BadSupplyCap();

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
        if (_isEnabled(SNAPSHOT)) {
            uint256 finalTotalAssets = totalAssets();

            if (finalTotalAssets > _supplyCap.resolve() && finalTotalAssets > _snapshotTotalAssets) {
                revert SupplyCapExceeded();
            }

            // Disable the snapshot feature to allow future snapshots to be taken. There's no need to clear the total
            // assets snapshot itself.
            _disableFeature(SNAPSHOT);
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

    /// @notice Checks if a specific feature is enabled.
    /// @param index The feature index to check for.
    /// @return True if the feature is enabled, false otherwise.
    function _isEnabled(uint8 index) internal view returns (bool) {
        /// forge-lint: disable-next-line(incorrect-shift)
        return (_stateBitmap & (1 << index)) == 0;
    }

    /// @notice Initializes the provided feature.
    /// @dev Should be used to initialize the features when the contract is deployed.
    /// @param index The feature index to initialize.
    function _initializeFeature(uint8 index) internal {
        if (!_isEnabled(index)) revert AlreadyInitialized();
        _disableFeature(index);
    }

    /// @notice Enables a specific feature.
    /// @param index The feature index to enable.
    function _enableFeature(uint8 index) internal {
        /// forge-lint: disable-next-line(incorrect-shift)
        _stateBitmap = _stateBitmap & ~uint16(1 << index);
    }

    /// @notice Disables a specific feature.
    /// @param index The feature index to disable.
    function _disableFeature(uint8 index) internal {
        /// forge-lint: disable-next-line(incorrect-shift)
        _stateBitmap = _stateBitmap | uint16(1 << index);
    }

    /// @notice Takes a snapshot of the current total assets if not locked.
    function _takeSnapshot() internal virtual {
        if (_isEnabled(SNAPSHOT) || _supplyCap.resolve() == type(uint256).max) return;

        _updateCache();
        uint256 totalAssetCache = totalAssets();
        _enableFeature(SNAPSHOT);
        _snapshotTotalAssets = totalAssetCache > type(uint112).max ? type(uint112).max : uint112(totalAssetCache);
    }

    /// @notice Updates the cache with any necessary changes, i.e. interest accrual that may affect the snapshot.
    function _updateCache() internal virtual;
}
