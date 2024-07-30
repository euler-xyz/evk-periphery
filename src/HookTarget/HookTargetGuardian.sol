// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @title HookTargetGuardian
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that allows to pause operations that are hooked for the vaults that have this contract installed
/// as a hook target.
contract HookTargetGuardian is IHookTarget, AccessControl {
    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

    /// @notice The duration for which vaults remain paused.
    uint256 public constant PAUSE_DURATION = 1 days;

    /// @notice The cooldown period before vaults can be paused again.
    uint256 public constant PAUSE_COOLDOWN = PAUSE_DURATION + 1 days;

    /// @notice Error thrown when the vault is paused.
    error HTG_VaultPaused();

    /// @notice Event emitted when the vaults are paused.
    event Paused();

    /// @notice Event emitted when the vaults are unpaused.
    event Unpaused();

    /// @notice Struct to store pause data.
    /// @param wasUnpaused Indicates if the vaults were unpaused.
    /// @param lastPauseTimestamp The timestamp of the last pause.
    struct PauseData {
        bool wasUnpaused;
        uint48 lastPauseTimestamp;
    }

    /// @notice Variable to store the pause data.
    PauseData internal pauseData;

    /// @notice Constructor to set the initial admin of the contract.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Fallback function to revert if the vault is paused.
    fallback() external {
        if (isPaused()) revert HTG_VaultPaused();
    }

    /// @notice Pauses the vault operations.
    function pause() external onlyRole(GUARDIAN) {
        if (!isPausable()) return;

        pauseData = PauseData({wasUnpaused: false, lastPauseTimestamp: uint48(block.timestamp)});

        emit Paused();
    }

    /// @notice Unpauses the vault operations.
    function unpause() external onlyRole(GUARDIAN) {
        if (!isPaused()) return;

        pauseData.wasUnpaused = true;

        emit Unpaused();
    }

    /// @notice Checks if the vault using this hook target can be paused.
    /// @return bool True if the vault can be paused, false otherwise.
    function isPausable() public view returns (bool) {
        return pauseData.lastPauseTimestamp + PAUSE_COOLDOWN < block.timestamp;
    }

    /// @notice Checks if the vault using this hook target is currently paused.
    /// @return bool True if the vault is paused, false otherwise.
    function isPaused() public view returns (bool) {
        return !pauseData.wasUnpaused && pauseData.lastPauseTimestamp + PAUSE_DURATION >= block.timestamp;
    }
}
