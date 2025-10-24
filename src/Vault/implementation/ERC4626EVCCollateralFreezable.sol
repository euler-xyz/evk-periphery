// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {
    ERC4626EVCCollateralCappedPausable,
    ERC4626EVCCollateral,
    ERC4626EVC
} from "../implementation/ERC4626EVCCollateralCappedPausable.sol";

/// @title ERC4626EVCCollateralFreezable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible collateral-only ERC4626 vault implementation that allows pausing and freezing accounts.
abstract contract ERC4626EVCCollateralFreezable is ERC4626EVCCollateralCappedPausable {
    /// @notice Mapping indicating if a particular address prefix (EVC account family) is frozen.
    mapping(bytes19 addressPrefix => bool) internal _freezes;

    /// @notice Emitted when an address prefix (EVC account family) is frozen.
    event GovFrozen(bytes19 indexed addressPrefix);

    /// @notice Emitted when an address prefix (EVC account family) is unfrozen.
    event GovUnfrozen(bytes19 indexed addressPrefix);

    /// @notice Error thrown when the account is frozen.
    error Frozen();

    /// @notice Modifier to restrict access to the account when it is frozen.
    /// @param account The account to check.
    modifier whenNotFrozen(address account) virtual {
        if (isFrozen(account)) revert Frozen();
        _;
    }

    /// @notice Freezes all accounts sharing an address prefix.
    /// @param account The address whose prefix to freeze.
    function freeze(address account) public virtual onlyEVCAccountOwner governorOnly {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        bytes19 addressPrefix = _getAddressPrefix(account);
        if (_freezes[addressPrefix]) return;
        _freezes[addressPrefix] = true;
        emit GovFrozen(addressPrefix);
    }

    /// @notice Unfreezes all accounts sharing an address prefix.
    /// @param account The address whose prefix to unfreeze.
    function unfreeze(address account) public virtual onlyEVCAccountOwner governorOnly {
        if (evc.getAccountOwner(account) != account) revert InvalidAddress();
        bytes19 addressPrefix = _getAddressPrefix(account);
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
        returns (uint256 shares)
    {
        shares = ERC4626EVCCollateral.withdraw(assets, receiver, owner);
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
        returns (uint256 assets)
    {
        assets = ERC4626EVCCollateral.redeem(shares, receiver, owner);
    }

    /// @notice Checks whether a given account is frozen based on its address prefix.
    /// @param account The account to check.
    /// @return True if the account is frozen, false otherwise.
    function isFrozen(address account) public view virtual returns (bool) {
        bytes19 addressPrefix = _getAddressPrefix(account);
        return _freezes[addressPrefix];
    }
}
