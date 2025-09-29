// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC20BurnableMintable} from "./ERC20BurnableMintable.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title ERC20Synth
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice ERC20-compatible synthetic token with EVC support, role-based minting, burning, and supply management.
/// @dev This contract is designed for token bridging and synthetic asset vaults. Minting is controlled by MINTER_ROLE,
/// and minting capacity is tracked per minter. The REVOKE_MINTER_ROLE can revoke minting rights in emergencies.
/// The contract supports excluding certain addresses from total supply calculations (e.g., vaults).
contract ERC20Synth is ERC20BurnableMintable, EVCUtil {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Struct holding minting capacity and minted amount for a minter.
    struct MinterData {
        uint128 capacity;
        uint128 minted;
    }

    /// @notice Role that allows allocation and deallocation to vaults.
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    /// @notice Mapping of minter address to their minting data (capacity and minted amount).
    mapping(address => MinterData) public minters;

    /// @notice Set of addresses to ignore for total supply calculations (e.g., vaults, contract itself).
    EnumerableSet.AddressSet internal _ignoredForTotalSupply;

    /// @notice Emitted when a minter's capacity is set or updated.
    /// @param minter The address of the minter.
    /// @param capacity The new minting capacity for the minter.
    event MinterCapacitySet(address indexed minter, uint256 capacity);

    /// @notice Error thrown when a minter exceeds their minting capacity.
    error CapacityReached();

    /// @notice Deploys the ESynth contract.
    /// @param evc_ Address of the EVC (Ethereum Vault Connector).
    /// @param admin_ Address to be granted DEFAULT_ADMIN_ROLE.
    /// @param name_ Name of the token.
    /// @param symbol_ Symbol of the token.
    /// @param decimals_ Number of decimals for the token.
    constructor(address evc_, address admin_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20BurnableMintable(admin_, name_, symbol_, decimals_)
        EVCUtil(evc_)
    {
        _ignoredForTotalSupply.add(address(this));
    }

    /// @notice Grants a role to an account. Only callable by EVC account owner.
    /// @param role The role to grant.
    /// @param account The address to grant the role to.
    function grantRole(bytes32 role, address account)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.grantRole(role, account);
    }

    /// @notice Revokes a role from an account. Only callable by EVC account owner.
    /// @param role The role to revoke.
    /// @param account The address to revoke the role from.
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.revokeRole(role, account);
    }

    /// @notice Renounces a role for the calling account. Only callable by EVC account owner.
    /// @param role The role to renounce.
    /// @param callerConfirmation The address of the caller (must match msg.sender).
    function renounceRole(bytes32 role, address callerConfirmation)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.renounceRole(role, callerConfirmation);
    }

    /// @notice Sets the minting capacity for a minter and grants MINTER_ROLE if not already granted.
    /// @param minter The address of the minter.
    /// @param capacity The new minting capacity for the minter.
    function setCapacity(address minter, uint128 capacity) external onlyEVCAccountOwner onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
        minters[minter].capacity = capacity;
        emit MinterCapacitySet(minter, capacity);
    }

    /// @notice Mints new tokens to a specified account, respecting the minter's capacity.
    /// @param _account The address to receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _account, uint256 _amount) external override onlyEVCAccountOwner onlyRole(MINTER_ROLE) {
        address sender = _msgSender();
        MinterData memory minterCache = minters[sender];

        if (_amount == 0) return;

        // If the minter has a finite capacity, check for overflow and capacity.
        if (
            minterCache.capacity != type(uint128).max
                && (
                    _amount > type(uint128).max - minterCache.minted
                        || minterCache.capacity < uint256(minterCache.minted) + _amount
                )
        ) {
            revert CapacityReached();
        }

        // Only update minted amount if the minter has a finite capacity.
        if (minterCache.capacity != type(uint128).max) {
            minterCache.minted += uint128(_amount); // safe to down-cast because amount <= capacity <= max uint128
            minters[sender] = minterCache;
        }

        _mint(_account, _amount);
    }

    /// @notice Burns tokens from the caller's balance and decreases their minted amount.
    /// @param _amount The amount of tokens to burn.
    function burn(uint256 _amount) public override {
        address sender = _msgSender();
        _decreaseMinted(sender, _amount);
        _burn(sender, _amount);
    }

    /// @notice Burns tokens from another account, using allowance if required, and decreases their minted amount.
    /// @param _account The account to burn tokens from.
    /// @param _amount The amount of tokens to burn.
    function burnFrom(address _account, uint256 _amount) public override {
        address sender = _msgSender();

        if (_amount == 0) return;

        // Allowance check: required unless burning from self, or admin burning from contract itself.
        if (_account != sender && !(_account == address(this) && hasRole(DEFAULT_ADMIN_ROLE, sender))) {
            _spendAllowance(_account, sender, _amount);
        }

        _decreaseMinted(_account, _amount);
        _burn(_account, _amount);
    }

    /// @notice Allocates tokens from this contract to a vault and adds the vault to ignored supply.
    /// @param _vault The vault address to allocate to.
    /// @param _amount The amount of tokens to allocate.
    function allocate(address _vault, uint256 _amount) external onlyEVCAccountOwner onlyRole(ALLOCATOR_ROLE) {
        _ignoredForTotalSupply.add(_vault);
        _approve(address(this), _vault, _amount, true);
        IEVault(_vault).deposit(_amount, address(this));
    }

    /// @notice Deallocates tokens from a vault back to this contract.
    /// @param _vault The vault address to deallocate from.
    /// @param _amount The amount of tokens to deallocate.
    function deallocate(address _vault, uint256 _amount) external onlyEVCAccountOwner onlyRole(ALLOCATOR_ROLE) {
        IEVault(_vault).withdraw(_amount, address(this), address(this));
    }

    /// @notice Adds an account to the set of addresses ignored for total supply.
    /// @param account The address to add.
    /// @return success True if the account was added, false if it was already present.
    function addIgnoredForTotalSupply(address account)
        external
        onlyEVCAccountOwner
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool success)
    {
        return _ignoredForTotalSupply.add(account);
    }

    /// @notice Removes an account from the set of addresses ignored for total supply.
    /// @param account The address to remove.
    /// @return success True if the account was removed, false if it was not present.
    function removeIgnoredForTotalSupply(address account)
        external
        onlyEVCAccountOwner
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool success)
    {
        return _ignoredForTotalSupply.remove(account);
    }

    /// @notice Checks if an account is ignored for total supply.
    /// @param account The address to check.
    /// @return isIgnored True if the account is ignored, false otherwise.
    function isIgnoredForTotalSupply(address account) external view returns (bool isIgnored) {
        return _ignoredForTotalSupply.contains(account);
    }

    /// @notice Returns all accounts ignored for total supply.
    /// @return accounts Array of ignored addresses.
    function getAllIgnoredForTotalSupply() external view returns (address[] memory accounts) {
        return _ignoredForTotalSupply.values();
    }

    /// @notice Returns the total supply, excluding balances of ignored accounts.
    /// @return total The effective total supply.
    function totalSupply() public view override returns (uint256 total) {
        total = super.totalSupply();

        uint256 ignoredLength = _ignoredForTotalSupply.length();
        for (uint256 i = 0; i < ignoredLength; ++i) {
            total -= balanceOf(_ignoredForTotalSupply.at(i));
        }
        return total;
    }

    /// @notice Decreases the minted amount for an account, resetting to zero if burning more than minted.
    /// @param _account The account whose minted amount to decrease.
    /// @param _amount The amount to decrease.
    function _decreaseMinted(address _account, uint256 _amount) internal {
        MinterData memory minterCache = minters[_account];

        // If burning more than minted, reset minted to 0
        unchecked {
            // down-casting is safe because amount < minted <= max uint128
            minterCache.minted = minterCache.minted > _amount ? minterCache.minted - uint128(_amount) : 0;
        }
        minters[_account] = minterCache;
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @return msgSender The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address msgSender) {
        return EVCUtil._msgSender();
    }
}
