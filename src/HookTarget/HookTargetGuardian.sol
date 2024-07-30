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
    uint256 public constant PAUSE_COOLDOWN = 1 days;

    /// @notice Error thrown when the vault is paused.
    error HTG_VaultPaused();

    /// @notice Event emitted when the vaults are paused.
    event Paused();

    /// @notice Event emitted when the vaults are unpaused.
    event Unpaused();

    /// @notice The timestamp of the last pause.
    uint256 internal lastPauseTimestamp;

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
    /// @dev The vault can only be paused if it is currently not paused AND the cooldown period has passed since the
    /// last pause.
    function pause() external onlyRole(GUARDIAN) {
        if (!isPausable()) return;

        lastPauseTimestamp = block.timestamp;
        emit Paused();
    }

    /// @notice Unpauses the vault operations.
    /// @dev The vault can only be unpaused if it is currently paused AND if:
    /// - the guardian is calling the function, OR
    /// - the pause duration has passed since the last pause
    function unpause() external {
        if (!isUnpausable(hasRole(GUARDIAN, _msgSender()))) return;

        lastPauseTimestamp = 0;
        emit Unpaused();
    }

    /// @notice Checks if the vault using this hook target is currently paused.
    /// @return bool True if the vault is paused, false otherwise.
    function isPaused() public view returns (bool) {
        return lastPauseTimestamp + PAUSE_DURATION >= block.timestamp;
    }

    /// @notice Checks if the vault using this hook target can be paused.
    /// @return bool True if the vault can be paused, false otherwise.
    function isPausable() public view returns (bool) {
        return lastPauseTimestamp == 0 && lastPauseTimestamp + PAUSE_DURATION + PAUSE_COOLDOWN < block.timestamp;
    }

    /// @notice Checks if the vault using this hook target can be unpaused.
    /// @param guardianCalling Whether the guardian is calling the function.
    /// @return bool True if the vault can be unpaused, false otherwise.
    function isUnpausable(bool guardianCalling) public view returns (bool) {
        return lastPauseTimestamp != 0
            && (guardianCalling || (!guardianCalling && lastPauseTimestamp + PAUSE_DURATION < block.timestamp));
    }
}
