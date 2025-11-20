// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {ERC4626, ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20Permit2Lib, IERC20 as SafeERC20Permit2LibIERC20} from "euler-earn/libraries/SafeERC20Permit2Lib.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title ERC4626EVC
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice EVC-compatible ERC4626 vault. Implements internal balance tracking, EVK-style `VIRTUAL_AMOUNT` conversions
/// and permit2 support.
abstract contract ERC4626EVC is EVCUtil, ERC4626 {
    using Math for uint256;

    /// @dev The virtual amount added to total shares and total assets.
    uint256 internal constant VIRTUAL_AMOUNT = 1e6;

    /// @dev The address of the permit2 contract.
    address public immutable permit2Address;

    /// @dev The total assets of the vault.
    uint256 internal _totalAssets;

    /// @notice Error thrown when the address is invalid.
    error InvalidAddress();

    /// @dev Initializes the contract.
    /// @param evc The EVC address.
    /// @param permit2 The address of the permit2 contract.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    constructor(address evc, address permit2, address asset, string memory name, string memory symbol)
        EVCUtil(evc)
        ERC4626(IERC20(asset))
        ERC20(name, symbol)
    {
        permit2Address = permit2;
    }

    /// @notice Returns the total assets of the vault.
    /// @return The total assets.
    function totalAssets() public view virtual override returns (uint256) {
        return _totalAssets;
    }

    /// @dev Internal conversion function (from assets to shares) with support for rounding direction.
    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + VIRTUAL_AMOUNT, totalAssets() + VIRTUAL_AMOUNT, rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction.
    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return shares.mulDiv(totalAssets() + VIRTUAL_AMOUNT, totalSupply() + VIRTUAL_AMOUNT, rounding);
    }

    /// @dev Deposit/mint common workflow.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        SafeERC20Permit2Lib.safeTransferFromWithPermit2(
            SafeERC20Permit2LibIERC20(address(asset())), caller, address(this), assets, permit2Address
        );
        _mint(receiver, shares);
        _totalAssets = _totalAssets + assets;
        emit Deposit(caller, receiver, assets, shares);
    }

    /// @dev Withdraw/redeem common workflow.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        // assets sent to EVC sub-accounts would be lost, as the private key for a sub-account is not known
        address evcOwner = evc.getAccountOwner(receiver);
        if (evcOwner != address(0) && evcOwner != receiver) {
            revert InvalidAddress();
        }

        _totalAssets = _totalAssets - assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    function _msgSender() internal view virtual override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}
