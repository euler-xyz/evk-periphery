// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @title BaseHookTarget
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Base contract for hook targets associated with the vaults deployed by the EVK factory.
abstract contract BaseHookTarget is IHookTarget {
    /// @notice The EVault factory contract.
    GenericFactory public immutable eVaultFactory;

    /// @notice Constructor
    /// @param _eVaultFactory The address of the EVault factory contract which deployed the vaults associated with
    /// this hook target.
    constructor(address _eVaultFactory) {
        eVaultFactory = GenericFactory(_eVaultFactory);
    }

    /// @inheritdoc IHookTarget
    /// @dev This function returns the expected magic value only if the caller is a proxy deployed by the recognized
    /// EVault factory.
    function isHookTarget() external view override returns (bytes4) {
        if (eVaultFactory.isProxy(msg.sender)) return this.isHookTarget.selector;
        else return 0;
    }

    /// @notice Retrieves the message sender in the context of the calling vault.
    /// @dev If the caller is a vault deployed by the recognized EVault factory, this function extracts the target
    /// contract address from the calldata. Otherwise, it returns the original caller.
    /// @return msgSender The address of the message sender.
    function _msgSender() internal view virtual returns (address msgSender) {
        if (!eVaultFactory.isProxy(msg.sender)) return msg.sender;

        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}
