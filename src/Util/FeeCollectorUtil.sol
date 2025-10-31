// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControl, IAccessControl, Context} from "openzeppelin-contracts/access/AccessControl.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title FeeCollectorUtil
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that collects and converts fees from multiple vaults.
contract FeeCollectorUtil is AccessControlEnumerable, EVCUtil {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Role that can add and remove vaults from the list
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    /// @notice The ERC20 token used for fees
    IERC20 public immutable feeToken;

    /// @notice Internal set of vault addresses from which fees are collected
    EnumerableSet.AddressSet internal _vaultsList;

    /// @notice Emitted when a vault is added to the list
    event VaultAdded(address indexed vault);

    /// @notice Emitted when a vault is removed from the list
    event VaultRemoved(address indexed vault);

    /// @notice Error thrown when a vault asset is not the same as the fee token
    error InvalidVault();

    /// @notice Initializes the FeeCollectorUtil contract
    /// @param _evc The address of the EVC contract
    /// @param _admin The address that will be granted the DEFAULT_ADMIN_ROLE
    /// @param _feeToken The address of the ERC20 token used for fees
    constructor(address _evc, address _admin, address _feeToken) EVCUtil(_evc) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        feeToken = IERC20(_feeToken);
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
    /// @param callerConfirmation The address of the caller (must match _msgSender()).
    function renounceRole(bytes32 role, address callerConfirmation)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.renounceRole(role, callerConfirmation);
    }

    /// @notice Allows recovery of any ERC20 tokens or native currency sent to this contract
    /// @param token The address of the token to recover. If address(0), the native currency is recovered.
    /// @param to The address to send the tokens to
    /// @param amount The amount of tokens to recover
    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success, "Native currency recovery failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Adds a vault to the list
    /// @param vault The address of the vault to add
    /// @return success True if the vault was successfully added, false if it was already in the list
    function addToVaultsList(address vault) external onlyRole(MAINTAINER_ROLE) returns (bool) {
        if (IEVault(vault).asset() != address(feeToken)) revert InvalidVault();

        bool success = _vaultsList.add(vault);
        if (success) emit VaultAdded(vault);
        return success;
    }

    /// @notice Removes a vault from the list
    /// @param vault The address of the vault to remove
    /// @return success True if the vault was successfully removed, false if it was not in the list
    function removeFromVaultsList(address vault) external onlyRole(MAINTAINER_ROLE) returns (bool) {
        bool success = _vaultsList.remove(vault);
        if (success) emit VaultRemoved(vault);
        return success;
    }

    /// @notice Collects and converts fees from all vaults in the list
    function collectFees() external virtual {
        _convertAndRedeemFees();
    }

    /// @notice Checks if a vault is in the list
    /// @param vault The address of the vault to check
    /// @return True if the vault is in the list, false otherwise
    function isInVaultsList(address vault) external view returns (bool) {
        return _vaultsList.contains(vault);
    }

    /// @notice Returns the complete list of vault addresses
    /// @return An array containing all vault addresses in the list
    function getVaultsList() external view returns (address[] memory) {
        return _vaultsList.values();
    }

    /// @dev Internal function to convert and redeem fees from all vaults in the list
    function _convertAndRedeemFees() internal {
        uint256 length = _vaultsList.length();
        for (uint256 i = 0; i < length; ++i) {
            address vault = _vaultsList.at(i);
            try IEVault(vault).convertFees() {
                try IEVault(vault).redeem(type(uint256).max, address(this), address(this)) {} catch {}
            } catch {}
        }
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @return msgSender The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address msgSender) {
        return EVCUtil._msgSender();
    }
}
