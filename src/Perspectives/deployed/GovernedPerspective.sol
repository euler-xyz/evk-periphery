// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title GovernedPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault is on the defined governed whitelist.
contract GovernedPerspective is EVCUtil, Ownable, BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Emitted when a vault is removed from the whitelist (unverified).
    /// @param vault The address of the vault that has been unverified.
    event PerspectiveUnverified(address indexed vault);

    /// @notice Creates a new GovernedPerspective instance.
    /// @param _evc The address of the EVC.
    /// @param _owner The address that will be set as the owner of the contract.
    constructor(address _evc, address _owner) EVCUtil(_evc) Ownable(_owner) BasePerspective(address(0)) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Governed Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address) internal virtual override onlyEVCAccountOwner onlyOwner {
        testProperty(true, type(uint256).max);
    }

    /// @notice Removes a vault from the whitelist (unverifies it)
    /// @param vault The address of the vault to be unverified
    function perspectiveUnverify(address vault) public virtual onlyEVCAccountOwner onlyOwner {
        if (verified.remove(vault)) {
            emit PerspectiveUnverified(vault);
        }
    }

    /// @dev Leaves the contract without owner. It will not be possible to call `onlyOwner` functions. Can only be
    /// called by the current owner.
    /// NOTE: Renouncing ownership will leave the contract without an owner, thereby disabling any functionality that is
    /// only available to the owner.
    function renounceOwnership() public virtual override onlyEVCAccountOwner {
        super.renounceOwnership();
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual override onlyEVCAccountOwner {
        super.transferOwnership(newOwner);
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}
