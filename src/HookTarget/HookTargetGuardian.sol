// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @title HookTargetGuardian
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that allows to pause operations that are hooked for the vaults that have this contract installed
/// as a hook target. The operations remain paused temporarily until either the PAUSE_DURATION elapses or the guardian
/// calls the unpause function, whichever occurs first.
contract HookTargetGuardian is IHookTarget, AccessControlEnumerable {
    /// @notice Indicates whether the vault operations are currently paused.
    bool paused;

    /// @notice The timestamp of the last pause.
    uint48 lastPauseTimestamp;

    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice The duration for which vaults remain paused.
    uint256 public immutable PAUSE_DURATION;

    /// @notice The cooldown period before vaults can be paused again.
    uint256 public immutable PAUSE_COOLDOWN;

    /// @notice Event emitted when the vaults are paused.
    event Paused();

    /// @notice Event emitted when the vaults are unpaused.
    event Unpaused();

    /// @notice Error thrown when the vault is paused.
    error HTG_VaultPaused();

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

    /// @notice Fallback function to revert if the vault is paused.
    fallback() external {
        if (isPaused()) revert HTG_VaultPaused();
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Pauses the vault operations.
    function pause() external onlyRole(GUARDIAN_ROLE) {
        if (!canBePaused()) return;

        paused = true;
        lastPauseTimestamp = uint48(block.timestamp);

        emit Paused();
    }

    /// @notice Unpauses the vault operations.
    function unpause() external onlyRole(GUARDIAN_ROLE) {
        if (!isPaused()) return;

        paused = false;

        emit Unpaused();
    }

    /// @notice Checks if the vault using this hook target is currently paused.
    /// @return bool True if the vault is paused, false otherwise.
    function isPaused() public view returns (bool) {
        return paused && lastPauseTimestamp + PAUSE_DURATION >= block.timestamp;
    }

    /// @notice Checks if the vault using this hook target can be paused.
    /// @return bool True if the vault can be paused, false otherwise.
    function canBePaused() public view returns (bool) {
        // The vault can be paused if the pause cooldown has passed since the last pause.
        return lastPauseTimestamp + PAUSE_COOLDOWN < block.timestamp;
    }

    /// @notice Calculates the remaining duration of the current pause period.
    /// @return The remaining pause duration in seconds.
    function remainingPauseDuration() public view returns (uint256) {
        if (!isPaused()) return 0;

        uint256 endTime = lastPauseTimestamp + PAUSE_DURATION;
        return endTime > block.timestamp ? endTime - block.timestamp : 0;
    }
}
