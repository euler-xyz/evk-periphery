// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Set, SetStorage} from "ethereum-vault-connector/Set.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @title HookTargetSplitter
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A hook target that delegates calls to a list of other hook targets.
contract HookTargetSplitter is IHookTarget {
    using Set for SetStorage;

    /// @notice Storage for the set of hook target addresses
    SetStorage internal hookTargetsSet;

    /// @notice Error thrown when an unexpected hook target is encountered
    error HTS_UnexpectedHookTarget();

    /// @notice Constructor to initialize the contract with the hook targets.
    /// @param hookTargets The addresses of the hook targets.
    constructor(address[] memory hookTargets) {
        for (uint256 i = 0; i < hookTargets.length; ++i) {
            hookTargetsSet.insert(hookTargets[i]);
        }
    }

    /// @notice Fallback function that delegates calls to all hook targets
    fallback() external {
        address[] memory hookTargets = hookTargetsSet.get();

        for (uint256 i = 0; i < hookTargets.length; ++i) {
            (bool success, bytes memory result) = hookTargets[i].delegatecall(msg.data);
            if (!success) RevertBytes.revertBytes(result);
        }
    }

    /// @inheritdoc IHookTarget
    /// @dev This function checks if all the hook targets are valid. Some hook targets might rely on the caller
    /// address, so this function must delegatecall to the hook targets.
    function isHookTarget() external view override returns (bytes4) {
        address[] memory hookTargets = hookTargetsSet.get();
        function (address) internal view returns (bool) isHookTargetPtr = asView(isHookTarget);

        for (uint256 i = 0; i < hookTargets.length; ++i) {
            if (!isHookTargetPtr(hookTargets[i])) return 0;
        }

        return this.isHookTarget.selector;
    }

    /// @notice Delegates a call to a specific hook target
    /// @param hookTarget The address of the hook target to delegate the call to
    /// @param data The calldata to be passed to the hook target
    /// @return The result of the delegatecall
    function delegatecallHookTarget(address hookTarget, bytes calldata data) external returns (bytes memory) {
        if (!hookTargetsSet.contains(hookTarget)) revert HTS_UnexpectedHookTarget();

        (bool success, bytes memory result) = hookTarget.delegatecall(data);
        if (!success) RevertBytes.revertBytes(result);

        return result;
    }

    /// @notice Retrieves the list of hook targets
    /// @return An array of addresses representing the hook targets
    function getHookTargets() external view returns (address[] memory) {
        return hookTargetsSet.get();
    }

    /// @notice Checks if the given address is a valid hook target
    /// @param hookTarget The address of the hook target to check
    /// @return A boolean indicating whether the address is a valid hook target
    function isHookTarget(address hookTarget) internal returns (bool) {
        (bool success, bytes memory result) = hookTarget.delegatecall(abi.encodeCall(IHookTarget.isHookTarget, ()));

        if (success && result.length == 32 && abi.decode(result, (bytes4)) == this.isHookTarget.selector) {
            return true;
        }

        return false;
    }

    /// @notice Cast the state mutability of a function pointer from `non-view` to `view`.
    /// @dev Credit to [z0age](https://twitter.com/z0age/status/1654922202930888704) for this trick.
    /// @param fn A pointer to a function with `non-view` (default) state mutability.
    /// @return fnAsView A pointer to the same function with its state mutability cast to `view`.
    function asView(function (address) internal returns (bool) fn)
        internal
        pure
        returns (function (address) internal view returns (bool) fnAsView)
    {
        assembly {
            fnAsView := fn
        }
    }
}
