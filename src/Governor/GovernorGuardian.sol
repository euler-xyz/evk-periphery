// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title GovernorGuardian
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited EVault governor contract that allows to pause vault operations.
contract GovernorGuardian is ReentrancyGuard, AccessControl {
    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

    /// @notice The duration after which the vault can be unpaused.
    uint256 public constant PAUSE_DURATION = 1 days;

    /// @notice The cooldown period before a vault can be paused again.
    uint256 public constant PAUSE_COOLDOWN = PAUSE_DURATION + 1 days;

    /// @notice Event emitted when a vault is paused.
    /// @param vault The vault that was paused.
    event Paused(address indexed vault);

    /// @notice Event emitted when a vault is unpaused.
    /// @param vault The vault that was unpaused.
    event Unpaused(address indexed vault);

    /// @notice Event emitted when the pause status of a vault changes.
    /// @param vault The address of the vault whose pause status changed.
    event PauseStatusChanged(address indexed vault);

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

    /// @notice Constructor to set the initial admin of the contract.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Pauses the given vaults.
    /// @param vaults The array of vault addresses to be paused.
    function pause(address[] calldata vaults) external nonReentrant onlyRole(GUARDIAN) {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!isPausable(vault)) continue;

            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            pauseDatas[vault] =
                PauseData({hookTarget: hookTarget, hookedOps: hookedOps, lastPauseTimestamp: uint48(block.timestamp)});

            IEVault(vault).setHookConfig(address(0), (OP_MAX_VALUE - 1));

            emit Paused(vault);
        }
    }

    /// @notice Unpauses the given vaults.
    /// @param vaults The array of vault addresses to be unpaused.
    function unpause(address[] calldata vaults) external nonReentrant {
        bool guardianCalling = hasRole(GUARDIAN, _msgSender());

        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!isUnpausable(vault, guardianCalling)) continue;

            address hookTarget = pauseDatas[vault].hookTarget;
            uint32 hookedOps = pauseDatas[vault].hookedOps;

            IEVault(vault).setHookConfig(hookTarget, hookedOps);

            emit Unpaused(vault);
        }
    }

    /// @notice Changes pause status of the selected operations for the given vaults.
    /// @param vaults The array of vault addresses to be unpaused.
    /// @param newHookedOps The new hooked operations bitmap.
    function changePauseStatus(address[] calldata vaults, uint32 newHookedOps)
        external
        nonReentrant
        onlyRole(GUARDIAN)
    {
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            if (!isPauseStatusChangeable(vault)) continue;

            IEVault(vault).setHookConfig(address(0), newHookedOps);

            emit PauseStatusChanged(vault);
        }
    }

    /// @notice Checks if the given vault can be paused.
    /// @param vault The address of the vault to check.
    /// @return bool True if the vault can be paused, false otherwise.
    function isPausable(address vault) public view returns (bool) {
        return pauseDatas[vault].lastPauseTimestamp + PAUSE_COOLDOWN < block.timestamp
            && IEVault(vault).governorAdmin() == address(this);
    }

    /// @notice Checks if the given vault can be unpaused.
    /// @param vault The address of the vault to check.
    /// @param guardianCalling Whether the guardian is calling the function.
    /// @return bool True if the vault can be unpaused, false otherwise.
    function isUnpausable(address vault, bool guardianCalling) public view returns (bool) {
        uint256 lastPauseTimestamp = pauseDatas[vault].lastPauseTimestamp;

        return lastPauseTimestamp != 0
            && (
                (guardianCalling && lastPauseTimestamp + PAUSE_DURATION >= block.timestamp)
                    || lastPauseTimestamp + PAUSE_DURATION < block.timestamp
            ) && IEVault(vault).governorAdmin() == address(this);
    }

    /// @notice Checks if the given vault is currently paused.
    /// @param vault The address of the vault to check.
    /// @return bool True if the vault is paused, false otherwise.
    function isPauseStatusChangeable(address vault) public view returns (bool) {
        return pauseDatas[vault].lastPauseTimestamp + PAUSE_DURATION >= block.timestamp
            && IEVault(vault).governorAdmin() == address(this);
    }
}
