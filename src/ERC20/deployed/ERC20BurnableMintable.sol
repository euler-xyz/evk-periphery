// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC20, ERC20Burnable} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title ERC20BurnableMintable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice An ERC20 token contract that allows to mint and burn tokens.
/// @dev The main purpose of this contract token bridging. Hence, this contract allows the caller with the MINTER_ROLE
/// to mint new tokens. In case of emergency, the caller with the REVOKE_MINTER_ROLE can revoke the MINTER_ROLE from an
/// address.
contract ERC20BurnableMintable is AccessControlEnumerable, ERC20Burnable, ERC20Permit {
    /// @notice Role that allows revoking minter role from addresses
    bytes32 public constant REVOKE_MINTER_ROLE = keccak256("REVOKE_MINTER_ROLE");

    /// @notice Role that allows minting new tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Number of decimals
    uint8 internal immutable _decimals;

    /// @notice Constructor for ERC20BurnableMintable
    /// @param admin_ Address of the contract admin who will have DEFAULT_ADMIN_ROLE
    /// @param name_ Name of the token
    /// @param symbol_ Symbol of the token
    /// @param decimals_ Number of decimals
    constructor(address admin_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _decimals = decimals_;
    }

    /// @notice Revokes the minter role from an address
    /// @param minter The address to revoke the minter role from
    function revokeMinterRole(address minter) external onlyRole(REVOKE_MINTER_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
    }

    /// @notice Mints new tokens and assigns them to an account
    /// @param _account The address that will receive the minted tokens
    /// @param _amount The amount of tokens to mint
    function mint(address _account, uint256 _amount) external virtual onlyRole(MINTER_ROLE) {
        _mint(_account, _amount);
    }

    /// @notice Returns the number of decimals for the token
    /// @return The number of decimals
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
