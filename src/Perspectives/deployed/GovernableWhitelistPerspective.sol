// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title GovernableWhitelistPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault is on the defined whitelist.
contract GovernableWhitelistPerspective is Ownable, BasePerspective {
    /// @notice Creates a new GovernableWhitelistPerspective instance.
    constructor(address owner) Ownable(owner) BasePerspective(address(0)) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Governable Whitelist Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address) internal virtual override onlyOwner {
        testProperty(true, type(uint256).max);
    }
}
