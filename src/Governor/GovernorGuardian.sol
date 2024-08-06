// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title GovernorGuardian
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited EVault governor contract that allows to pause vault operations. Operations can be unpaused by the
/// guardian or after the pause duration.
contract GovernorGuardian is AccessControlEnumerable {
    /// @notice Struct to store pause data for a vault.
    /// @param hookTarget The cached target address for the hook configuration.
    /// @param hookedOps The cached bitmap of the operations that are hooked.
    /// @param lastPauseTimestamp The timestamp of the last pause.
    struct PauseData {
        address hookTarget;
        uint32 hookedOps;
        uint48 lastPauseTimestamp;
    }

    /// @notice Mapping to store pause data for each vault.
    mapping(address => PauseData) internal pauseDatas;

    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice The duration after which the vault can be unpaused.
    uint256 public immutable PAUSE_DURATION;

    /// @notice The cooldown period before a vault can be paused again.
    uint256 public immutable PAUSE_COOLDOWN;

    /// @notice Event emitted when a vault is paused.
    /// @param vault The vault that was paused.
    event Paused(address indexed vault);

    /// @notice Event emitted when a vault is unpaused.
    /// @param vault The vault that was unpaused.
    event Unpaused(address indexed vault);

    /// @notice Event emitted when the pause status of a vault changes.
    /// @param vault The address of the vault whose pause status changed.
    event PauseStatusChanged(address indexed vault);

    /// @notice Constructor to initialize the contract with the given admin, pause duration, and pause cooldown.
    /// @param admin The address of the initial admin.
    /// @param pauseDuration The duration for which the vault remains paused.
    /// @param pauseCooldown The cooldown period before the vault can be paused again.
    constructor(address admin, uint256 pauseDuration, uint256 pauseCooldown) {
        require(pauseDuration > 0 && pauseCooldown > pauseDuration, "constructor error");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        PAUSE_DURATION = pauseDuration;
        PAUSE_COOLDOWN = pauseCooldown;
    }

    /// @notice Executes a call to a specified vault.
    /// @param vault The address of the vault to call.
    /// @param data The calldata to be called on the vault.
    /// @return result The result of the call.
    function adminCall(address vault, bytes calldata data)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bytes memory)
    {
        (bool success, bytes memory result) = vault.call(data);
        if (!success) RevertBytes.revertBytes(result);

        // If the call is a setHookConfig call, update the pause data.
        if (bytes4(data) == IEVault(vault).setHookConfig.selector) {
            (pauseDatas[vault].hookTarget, pauseDatas[vault].hookedOps) = IEVault(vault).hookConfig();
        }

        return result;
    }

    /// @notice Pauses the given vaults.
    /// @param vaults The array of vault addresses to be paused.
    function pause(address[] calldata vaults) external onlyRole(GUARDIAN_ROLE) {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!canBePaused(vault)) continue;

            // Cache the hook configuration.
            (pauseDatas[vault].hookTarget, pauseDatas[vault].hookedOps) = IEVault(vault).hookConfig();
            pauseDatas[vault].lastPauseTimestamp = uint48(block.timestamp);

            // Disable all operations.
            IEVault(vault).setHookConfig(address(0), (OP_MAX_VALUE - 1));

            emit Paused(vault);
        }
    }

    /// @notice Unpauses the given vaults.
    /// @param vaults The array of vault addresses to be unpaused.
    function unpause(address[] calldata vaults) external {
        bool guardianCalling = hasRole(GUARDIAN_ROLE, _msgSender());

        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!canBeUnpaused(vault, guardianCalling)) continue;

            // Restore the hook configuration.
            IEVault(vault).setHookConfig(pauseDatas[vault].hookTarget, pauseDatas[vault].hookedOps);

            emit Unpaused(vault);
        }
    }

    /// @notice Changes pause status of the selected operations for the given vaults.
    /// @param vaults The array of vault addresses to be unpaused.
    /// @param newHookedOps The new hooked operations bitmap.
    function changePauseStatus(address[] calldata vaults, uint32 newHookedOps) external onlyRole(GUARDIAN_ROLE) {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!canPauseStatusChange(vault)) continue;

            // Change the hook configuration, i.e. by unpausing the selected operations.
            IEVault(vault).setHookConfig(address(0), newHookedOps);

            emit PauseStatusChanged(vault);
        }
    }

    /// @notice Checks if the given vault can be paused.
    /// @param vault The address of the vault to check.
    /// @return bool True if the vault can be paused, false otherwise.
    function canBePaused(address vault) public view returns (bool) {
        // The vault can be paused if the pause cooldown has passed since the last pause.
        return pauseDatas[vault].lastPauseTimestamp + PAUSE_COOLDOWN < block.timestamp
            && IEVault(vault).governorAdmin() == address(this);
    }

    /// @notice Checks if the given vault can be unpaused.
    /// @param vault The address of the vault to check.
    /// @param guardianCalling Whether the guardian is calling the function.
    /// @return bool True if the vault can be unpaused, false otherwise.
    function canBeUnpaused(address vault, bool guardianCalling) public view returns (bool) {
        uint256 lastPauseTimestamp = pauseDatas[vault].lastPauseTimestamp;

        // The vault can be unpaused if the guardian is calling the function or if the pause duration has passed.
        // We must ensure that the hook config was previously cached by checking that the lastPauseTimestamp is not 0.
        return lastPauseTimestamp != 0 && (guardianCalling || lastPauseTimestamp + PAUSE_DURATION < block.timestamp)
            && IEVault(vault).governorAdmin() == address(this);
    }

    /// @notice Checks if the given vault status can be changed.
    /// @param vault The address of the vault to check.
    /// @return bool True if the vault status can be changed, false otherwise.
    function canPauseStatusChange(address vault) public view returns (bool) {
        PauseData memory pauseData = pauseDatas[vault];

        // The pause status can be changed if the cached hook target is the zero address to prevent vault
        // misconfiguration. Pause status can only be changed within the pause duration.
        return pauseData.hookTarget == address(0) && pauseData.lastPauseTimestamp + PAUSE_DURATION >= block.timestamp
            && IEVault(vault).governorAdmin() == address(this);
    }
}
