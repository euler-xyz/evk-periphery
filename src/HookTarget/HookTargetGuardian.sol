// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {EVault} from "evk/EVault/EVault.sol";

/// @title HookTargetGuardian
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A hook target that allows to pause specific selectors.
contract HookTargetGuardian is IHookTarget, Ownable {
    /// @notice The duration for which a selector remains paused.
    uint256 public constant PAUSE_DURATION = 1 days;

    /// @notice The cooldown period before a selector can be paused again.
    uint256 public constant PAUSE_COOLDOWN = 1 days;

    /// @notice Error thrown when an operation is paused.
    error HTG_OperationPaused();

    /// @notice Event emitted when a selector is paused.
    /// @param selector The selector that was paused.
    event Paused(bytes4 indexed selector);

    /// @notice Event emitted when a selector is unpaused.
    /// @param selector The selector that was unpaused.
    event Unpaused(bytes4 indexed selector);

    /// @notice Mapping to store the pause timestamps for each selector.
    mapping(bytes4 => uint256) internal pauseTimestamps;

    /// @notice Constructor to set the initial guardian (owner) of the contract.
    /// @param guardian The address of the initial guardian.
    constructor(address guardian) Ownable(guardian) {}

    /// @notice Fallback function to revert if the called selector is paused.
    fallback() external {
        if (isPaused(bytes4(msg.data))) revert HTG_OperationPaused();
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Checks if a given selector is currently paused.
    /// @param selector The selector to check.
    /// @return True if the selector is paused, false otherwise.
    function isPaused(bytes4 selector) public view returns (bool) {
        return pauseTimestamps[selector] + PAUSE_DURATION >= block.timestamp;
    }

    /// @notice Pauses the given selectors.
    /// @dev The selector can only be paused if it's pausable and if the cooldown period has passed since the last
    /// pause.
    /// @param selectors An array of selectors to be paused.
    function pause(bytes4[] memory selectors) external onlyOwner {
        for (uint256 i = 0; i < selectors.length; ++i) {
            bytes4 selector = selectors[i];
            if (
                isNonPausable(selector)
                    || pauseTimestamps[selector] + PAUSE_DURATION + PAUSE_COOLDOWN >= block.timestamp
            ) continue;

            pauseTimestamps[selector] = block.timestamp;
            emit Paused(selector);
        }
    }

    /// @notice Unpauses the given selectors.
    /// @dev The selector can only be unpaused if the operation is currently paused.
    /// @param selectors An array of selectors to be unpaused.
    function unpause(bytes4[] memory selectors) external onlyOwner {
        for (uint256 i = 0; i < selectors.length; ++i) {
            bytes4 selector = selectors[i];

            if (!isPaused(selector)) continue;

            pauseTimestamps[selector] = 1;
            emit Unpaused(selector);
        }
    }

    /// @notice Checks if a given selector is non-pausable.
    /// @param selector The selector to check.
    /// @return True if the selector is non-pausable, false otherwise.
    function isNonPausable(bytes4 selector) public pure returns (bool) {
        return selector == EVault.transfer.selector || selector == EVault.liquidate.selector
            || selector == EVault.checkVaultStatus.selector;
    }
}
