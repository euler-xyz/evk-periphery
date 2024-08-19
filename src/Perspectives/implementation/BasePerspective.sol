// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";

import {IPerspective} from "./interfaces/IPerspective.sol";
import {PerspectiveErrors} from "./PerspectiveErrors.sol";

/// @title BasePerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A base contract for implementing a perspective.
abstract contract BasePerspective is IPerspective, PerspectiveErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Transient {
        uint256 placeholder;
    }

    GenericFactory public immutable vaultFactory;

    EnumerableSet.AddressSet internal verified;
    Transient private transientVerified;
    Transient private transientErrors;
    Transient private transientVault;
    Transient private transientFailEarly;

    /// @notice Creates a new BasePerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    /// @inheritdoc IPerspective
    function name() public view virtual returns (string memory);

    /// @inheritdoc IPerspective
    function perspectiveVerify(address vault, bool failEarly) public virtual {
        bytes32 transientVerifiedHash;
        assembly {
            mstore(0, vault)
            mstore(32, transientVerified.slot)
            transientVerifiedHash := keccak256(0, 64)

            // if optimistically verified, return
            if eq(tload(transientVerifiedHash), true) { return(0, 0) }
        }

        // if already verified, return
        if (verified.contains(vault)) return;

        address _vault;
        bool _failEarly;
        assembly {
            _vault := tload(transientVault.slot)
            _failEarly := tload(transientFailEarly.slot)
            tstore(transientVault.slot, vault)
            tstore(transientFailEarly.slot, failEarly)

            // optimistically assume that the vault is verified
            tstore(transientVerifiedHash, true)
        }

        // perform the perspective verification
        perspectiveVerifyInternal(vault);

        uint256 errors;
        assembly {
            // restore the cached values
            tstore(transientVault.slot, _vault)
            tstore(transientFailEarly.slot, _failEarly)

            errors := tload(transientErrors.slot)
        }

        // if early fail was not requested, we need to check for any property errors that may have occurred.
        // otherwise, we would have already reverted if there were any property errors
        if (errors != 0) revert PerspectiveError(address(this), vault, errors);

        // set the vault as permanently verified
        verified.add(vault);
        emit PerspectiveVerified(vault);
    }

    /// @inheritdoc IPerspective
    function isVerified(address vault) public view virtual returns (bool) {
        return verified.contains(vault);
    }

    /// @inheritdoc IPerspective
    function verifiedLength() public view virtual returns (uint256) {
        return verified.length();
    }

    /// @inheritdoc IPerspective
    function verifiedArray() public view virtual returns (address[] memory) {
        return verified.values();
    }

    /// @notice Internal function to perform verification of a vault.
    /// @dev This function must be defined in derived contracts to implement specific verification logic.
    /// @dev This function should use the testProperty function to test the properties of the vault.
    /// @param vault The address of the vault to verify.
    function perspectiveVerifyInternal(address vault) internal virtual;

    /// @notice Tests a property condition and handles error based on the result.
    /// @param condition The boolean condition to test, typically a property of a vault. i.e governor == address(0)
    /// @param errorCode The error code to use if the condition fails.
    function testProperty(bool condition, uint256 errorCode) internal virtual {
        if (condition) return;
        if (errorCode == 0) revert PerspectivePanic();

        bool failEarly;
        assembly {
            failEarly := tload(transientFailEarly.slot)
        }

        if (failEarly) {
            address vault;
            assembly {
                vault := tload(transientVault.slot)
            }
            revert PerspectiveError(address(this), vault, errorCode);
        } else {
            assembly {
                let errors := tload(transientErrors.slot)
                tstore(transientErrors.slot, or(errors, errorCode))
            }
        }
    }
}
