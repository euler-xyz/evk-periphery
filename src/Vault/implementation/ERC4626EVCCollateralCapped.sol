// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {ERC4626EVC, ERC4626EVCCollateral, ERC20, IERC20} from "../implementation/ERC4626EVCCollateral.sol";
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

    /// @notice Modifier to prevent reentrancy on view functions.
    /// @dev Explicitly checking for message selector allows public view functions to be called internally
    modifier nonReentrantView(bytes4 selector) {
        if (bytes4(msg.data[:4]) == selector && _isEnabled(REENTRANCY)) revert Reentrancy();
        _;
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
        emit GovSetGovernorAdmin(admin);
    }

    /// @notice Sum of all eToken balances
    /// @return The total supply of the eToken
    function totalSupply()
        public
        view
        virtual
        override (ERC20, IERC20)
        nonReentrantView(this.totalSupply.selector)
        returns (uint256)
    {
        return super.totalSupply();
    }

    /// @notice Balance of a particular account, in eTokens
    /// @param account Address to query
    /// @return The balance of the account
    function balanceOf(address account)
        public
        view
        virtual
        override (ERC20, IERC20)
        nonReentrantView(this.balanceOf.selector)
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    /// @notice Retrieve the current allowance
    /// @param holder The account holding the eTokens
    /// @param spender Trusted address
    /// @return The allowance from holder for spender
    function allowance(address holder, address spender)
        public
        view
        virtual
        override (ERC20, IERC20)
        nonReentrantView(this.allowance.selector)
        returns (uint256)
    {
        return super.allowance(holder, spender);
    }

    /// @notice Returns the total assets of the vault.
    /// @return The total assets.
    function totalAssets() public view virtual override nonReentrantView(this.totalAssets.selector) returns (uint256) {
        return super.totalAssets();
    }

    /// @notice Calculate amount of assets corresponding to the requested shares amount
    /// @param shares Amount of shares to convert
    /// @return The amount of assets
    function convertToAssets(uint256 shares)
        public
        view
        virtual
        override
        nonReentrantView(this.convertToAssets.selector)
        returns (uint256)
    {
        return super.convertToAssets(shares);
    }

    /// @notice Calculate amount of shares corresponding to the requested assets amount
    /// @param assets Amount of assets to convert
    /// @return The amount of shares
    function convertToShares(uint256 assets)
        public
        view
        virtual
        override
        nonReentrantView(this.convertToShares.selector)
        returns (uint256)
    {
        return super.convertToShares(assets);
    }

    /// @notice Fetch the maximum amount of assets a user can deposit
    /// @param account Address to query
    /// @return The max amount of assets the account can deposit
    function maxDeposit(address account)
        public
        view
        virtual
        override
        nonReentrantView(this.maxDeposit.selector)
        returns (uint256)
    {
        uint256 cap = _supplyCap.resolve();
        if (cap == type(uint256).max) return super.maxDeposit(account);

        uint256 totalAssetsCache = totalAssets();
        if (totalAssetsCache >= cap) return 0;
        unchecked {
            return cap - totalAssetsCache;
        }
    }

    /// @notice Calculate an amount of shares that would be created by depositing assets
    /// @param assets Amount of assets deposited
    /// @return Amount of shares received
    function previewDeposit(uint256 assets)
        public
        view
        virtual
        override
        nonReentrantView(this.previewDeposit.selector)
        returns (uint256)
    {
        return super.previewDeposit(assets);
    }

    /// @notice Fetch the maximum amount of shares a user can mint
    /// @param account Address to query
    /// @return The max amount of shares the account can mint
    function maxMint(address account)
        public
        view
        virtual
        override
        nonReentrantView(this.maxMint.selector)
        returns (uint256)
    {
        uint256 cap = _supplyCap.resolve();
        if (cap == type(uint256).max) return super.maxMint(account);

        uint256 totalAssetsCache = totalAssets();
        if (totalAssetsCache >= cap) return 0;

        return previewDeposit(cap - totalAssetsCache);
    }

    /// @notice Calculate an amount of assets that would be required to mint requested amount of shares
    /// @param shares Amount of shares to be minted
    /// @return Required amount of assets
    function previewMint(uint256 shares)
        public
        view
        virtual
        override
        nonReentrantView(this.previewMint.selector)
        returns (uint256)
    {
        return super.previewMint(shares);
    }

    /// @notice Fetch the maximum amount of assets a user is allowed to withdraw
    /// @param owner Account holding the shares
    /// @return The maximum amount of assets the owner is allowed to withdraw
    function maxWithdraw(address owner)
        public
        view
        virtual
        override
        nonReentrantView(this.maxWithdraw.selector)
        returns (uint256)
    {
        return super.maxWithdraw(owner);
    }

    /// @notice Calculate the amount of shares that will be burned when withdrawing requested amount of assets
    /// @param assets Amount of assets withdrawn
    /// @return Amount of shares burned
    function previewWithdraw(uint256 assets)
        public
        view
        virtual
        override
        nonReentrantView(this.previewWithdraw.selector)
        returns (uint256)
    {
        return super.previewWithdraw(assets);
    }

    /// @notice Fetch the maximum amount of shares a user is allowed to redeem for assets
    /// @param owner Account holding the shares
    /// @return The maximum amount of shares the owner is allowed to redeem
    function maxRedeem(address owner)
        public
        view
        virtual
        override
        nonReentrantView(this.maxRedeem.selector)
        returns (uint256)
    {
        return super.maxRedeem(owner);
    }

    /// @notice Calculate the amount of assets that will be transferred when redeeming requested amount of shares
    /// @param shares Amount of shares redeemed
    /// @return Amount of assets transferred
    function previewRedeem(uint256 shares)
        public
        view
        virtual
        override
        nonReentrantView(this.previewRedeem.selector)
        returns (uint256)
    {
        return super.previewRedeem(shares);
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

    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override callThroughEVC nonReentrant returns (bool) {
        return super.transfer(to, amount);
    }

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        callThroughEVC
        nonReentrant
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /// @notice Allow spender to access an amount of your eTokens
    /// @param spender Trusted address
    /// @param amount Use max uint for "infinite" allowance
    /// @return True if approval succeeded
    function approve(address spender, uint256 amount)
        public
        virtual
        override (ERC20, IERC20)
        nonReentrant
        returns (bool)
    {
        return super.approve(spender, amount);
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
        evc.requireVaultStatusCheck();
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
        evc.requireVaultStatusCheck();
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
    /// @param index The feature index to initialize.
    /// @dev Should be used to initialize the features when the contract is deployed. Initialization ensures, among
    /// others, that an inheriting contract will not be able to reuse a conflicting feature index
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
