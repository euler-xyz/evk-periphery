// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {
    ERC4626EVCCollateralCapped,
    ERC4626EVCCollateral,
    ERC4626EVC
} from "../implementation/ERC4626EVCCollateralCapped.sol";

/// @title ERC4626EVCCollateralFreezable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation that allows pausing and freezing accounts.
abstract contract ERC4626EVCCollateralFreezable is ERC4626EVCCollateralCapped {
    /// @notice Pause feature index.
    uint8 internal constant PAUSE = 2;

    /// @notice Mapping indicating if a particular address prefix (EVC account family) is frozen.
    mapping(bytes19 addressPrefix => bool) internal _freezes;

    /// @notice Emitted when the contract is paused.
    event GovPaused();

    /// @notice Emitted when the contract is unpaused.
    event GovUnpaused();

    /// @notice Emitted when an address prefix (EVC account family) is frozen.
    event GovFrozen(bytes19 indexed addressPrefix);

    /// @notice Emitted when an address prefix (EVC account family) is unfrozen.
    event GovUnfrozen(bytes19 indexed addressPrefix);

    /// @notice Error thrown when the contract is paused.
    error Paused();

    /// @notice Error thrown when the account is frozen.
    error Frozen();

    /// @notice Modifier to restrict access to the contract when it is paused.
    modifier whenNotPaused() {
        if (_isEnabled(PAUSE)) revert Paused();
        _;
    }

    /// @notice Modifier to restrict access to the account when it is frozen.
    /// @param account The account to check.
    modifier whenNotFrozen(address account) {
        if (isFrozen(account)) revert Frozen();
        _;
    }

    /// @notice Initializes the contract and initializes the pause feature.
    constructor() {
        _initializeFeature(PAUSE);
    }

    /// @notice Pauses the contract.
    function pause() public onlyEVCAccountOwner governorOnly {
        if (_isEnabled(PAUSE)) return;
        _enableFeature(PAUSE);
        emit GovPaused();
    }

    /// @notice Unpauses the contract.
    function unpause() public onlyEVCAccountOwner governorOnly {
        if (!_isEnabled(PAUSE)) return;
        _disableFeature(PAUSE);
        emit GovUnpaused();
    }

    /// @notice Freezes all accounts sharing an address prefix. A frozen account's balance can not change.
    /// @param addressPrefix The address prefix to freeze.
    function freeze(bytes19 addressPrefix) public onlyEVCAccountOwner governorOnly {
        if (_freezes[addressPrefix]) return;
        _freezes[addressPrefix] = true;
        emit GovFrozen(addressPrefix);
    }

    /// @notice Unfreezes all accounts sharing an address prefix.
    /// @param addressPrefix The address prefix to unfreeze.
    function unfreeze(bytes19 addressPrefix) public onlyEVCAccountOwner governorOnly {
        if (!_freezes[addressPrefix]) return;
        _freezes[addressPrefix] = false;
        emit GovUnfrozen(addressPrefix);
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
        whenNotFrozen(_msgSender())
        whenNotFrozen(to)
        returns (bool result)
    {
        result = ERC4626EVCCollateral.transfer(to, amount);
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
        whenNotFrozen(from)
        whenNotFrozen(to)
        returns (bool result)
    {
        result = ERC4626EVCCollateral.transferFrom(from, to, amount);
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
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 shares)
    {
        shares = ERC4626EVCCollateral.deposit(assets, receiver);
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
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 assets)
    {
        assets = ERC4626EVCCollateral.mint(shares, receiver);
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
        whenNotFrozen(owner)
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 shares)
    {
        shares = ERC4626EVCCollateral.withdraw(assets, receiver, owner);
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
        whenNotPaused
        whenNotFrozen(owner)
        whenNotFrozen(receiver)
        takeSnapshot
        returns (uint256 assets)
    {
        assets = ERC4626EVCCollateral.redeem(shares, receiver, owner);
        evc.requireVaultStatusCheck();
    }

    /// @notice Returns shares balance of an account
    /// @param account Address to query
    /// @return The balance of the account
    /// @dev Returns 0 balance when checks are in progress and account is freezed or paused
    /// to zero out collateral value and prevent taking out borrows in this state
    function balanceOf(address account) public view virtual override returns (uint256) {
        if (evc.areChecksInProgress() && (isFrozen(account) || isPaused())) {
            return 0;
        }

        return super.balanceOf(account);
    }

    /// @notice Fetch the maximum amount of assets a user can deposit
    /// @param receiver Address to query
    /// @return The max amount of assets the account can deposit
    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (isFrozen(_getAddressPrefix(receiver)) || isPaused()) return 0;
        return super.maxDeposit(receiver);
    }

    /// @notice Fetch the maximum amount of shares a user can mint
    /// @param receiver Address to query
    /// @return The max amount of shares the account can mint
    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (isFrozen(_getAddressPrefix(receiver)) || isPaused()) return 0;
        return super.maxMint(receiver);
    }

    /// @notice Fetch the maximum amount of assets a user is allowed to withdraw
    /// @param owner Account to query
    /// @return The maximum amount of assets the owner is allowed to withdraw
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (isFrozen(_getAddressPrefix(owner)) || isPaused()) return 0;
        return super.maxWithdraw(owner);
    }

    /// @notice Fetch the maximum amount of shares a user is allowed to redeem for assets
    /// @param owner Account to query
    /// @return The maximum amount of shares the owner is allowed to redeem
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (isFrozen(_getAddressPrefix(owner)) || isPaused()) return 0;
        return super.maxRedeem(owner);
    }

    /// @notice Checks whether the contract is paused.
    /// @return True if the contract is paused, false otherwise.
    function isPaused() public view returns (bool) {
        return _isEnabled(PAUSE);
    }

    /// @notice Checks whether a given address prefix (EVC account family) is frozen.
    /// @param addressPrefix The adress prefix to check.
    /// @return True if the address prefix is frozen, false otherwise.
    function isFrozen(bytes19 addressPrefix) public view returns (bool) {
        return _freezes[addressPrefix];
    }

    /// @notice Checks whether a given account and it's EVC account family is frozen.
    /// @param account The account to check.
    /// @return True if the account is frozen, false otherwise.
    function isFrozen(address account) public view returns (bool) {
        return _freezes[_getAddressPrefix(account)];
    }
}
