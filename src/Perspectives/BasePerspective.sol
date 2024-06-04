// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {IERC20} from "evk/EVault/IEVault.sol";

import {IPerspective} from "./interfaces/IPerspective.sol";
import {PerspectiveErrors} from "./PerspectiveErrors.sol";

abstract contract BasePerspective is IPerspective, PerspectiveErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Transient {
        uint256 placeholder;
    }

    GenericFactory internal immutable vaultFactory;

    EnumerableSet.AddressSet private verified;
    Transient private transientVerified;
    Transient private transientErrors;
    Transient private transientVault;
    Transient private transientFailEarly;

    constructor(address vaultFactory_) {
        vaultFactory = GenericFactory(vaultFactory_);
    }

    /// @inheritdoc IPerspective
    function name() public view virtual returns (string memory);

    /// @inheritdoc IPerspective
    function perspectiveVerify(address vault, bool failEarly) public {
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
    function isVerified(address vault) public view returns (bool) {
        return verified.contains(vault);
    }

    /// @inheritdoc IPerspective
    function verifiedLength() public view returns (uint256) {
        return verified.length();
    }

    /// @inheritdoc IPerspective
    function verifiedArray() public view returns (address[] memory) {
        return verified.values();
    }

    function perspectiveVerifyInternal(address vault) internal virtual {}

    function testProperty(bool condition, uint256 errorCode) internal {
        if (condition) return;

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

    function getTokenName(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.name.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }

    function getTokenSymbol(address asset) internal view returns (string memory) {
        // Handle MKR like tokens returning bytes32
        (bool success, bytes memory data) = address(asset).staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        if (!success) RevertBytes.revertBytes(data);
        return data.length <= 32 ? string(data) : abi.decode(data, (string));
    }
}
