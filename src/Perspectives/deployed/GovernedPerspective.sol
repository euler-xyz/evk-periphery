// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title GovernedPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault is on the defined governed whitelist.
contract GovernedPerspective is Ownable, BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Emitted when a vault is removed from the whitelist (unverified).
    /// @param vault The address of the vault that has been unverified.
    event PerspectiveUnverified(address indexed vault);

    /// @notice Creates a new GovernedPerspective instance.
    /// @param owner The address that will be set as the owner of the contract.
    constructor(address owner) Ownable(owner) BasePerspective(address(0)) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Governed Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address) internal virtual override onlyOwner {
        testProperty(true, type(uint256).max);
    }

    /// @notice Removes a vault from the whitelist (unverifies it)
    /// @param vault The address of the vault to be unverified
    function perspectiveUnverify(address vault) public virtual onlyOwner {
        if (verified.remove(vault)) {
            emit PerspectiveUnverified(vault);
        }
    }
}
