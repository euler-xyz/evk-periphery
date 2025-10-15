// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC4626EVCCompatible, ERC20, IERC20} from "./ERC4626EVCCompatible.sol";

/// @title ERC4626EVCCompatibleCollateral
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVK-compatible collateral-only ERC4626 vault.
abstract contract ERC4626EVCCompatibleCollateral is ERC4626EVCCompatible {
    /// @notice Transfers a certain amount of shares to a recipient.
    /// @param to The recipient of the transfer.
    /// @param amount The amount shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transfer(address to, uint256 amount) public virtual override (IERC20, ERC20) returns (bool) {
        bool result = super.transfer(to, amount);
        evc.requireAccountStatusCheck(_msgSender());
        return result;
    }

    /// @notice Transfers a certain amount of shares from a sender to a recipient.
    /// @param from The sender of the transfer.
    /// @param to The recipient of the transfer.
    /// @param amount The amount of shares to transfer.
    /// @return A boolean indicating whether the transfer was successful.
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override (IERC20, ERC20)
        returns (bool)
    {
        bool result = super.transferFrom(from, to, amount);
        evc.requireAccountStatusCheck(from);
        return result;
    }

    /// @notice Deposits a certain amount of assets for a receiver.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the deposit.
    /// @return shares The shares equivalent to the deposited assets.
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
    }

    /// @notice Mints a certain amount of shares for a receiver.
    /// @param shares The shares to mint.
    /// @param receiver The receiver of the mint.
    /// @return assets The assets equivalent to the minted shares.
    function mint(uint256 shares, address receiver) public virtual override returns (uint256 assets) {
        assets = super.mint(shares, receiver);
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
        returns (uint256 shares)
    {
        shares = super.withdraw(assets, receiver, owner);
        evc.requireAccountStatusCheck(owner);
    }

    /// @notice Redeems a certain amount of shares for a receiver.
    /// @param shares The shares to redeem.
    /// @param receiver The receiver of the redemption.
    /// @param owner The owner of the shares.
    /// @return assets The assets equivalent to the redeemed shares.
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256 assets) {
        assets = super.redeem(shares, receiver, owner);
        evc.requireAccountStatusCheck(owner);
    }
}
