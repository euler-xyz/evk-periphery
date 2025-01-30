// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHookTarget} from "../../HookTarget/BaseHookTarget.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

interface IWhitelist {
    function isWalletAllowed(address _user) external view returns (bool);
}

/// @title HookTarget
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that enforces the receiver to be whitelisted for skim operation.
contract HookTarget is BaseHookTarget {
    address public immutable evc;
    address public immutable whitelist;

    constructor(address _evc, address _whitelist, address _eVaultFactory) BaseHookTarget(_eVaultFactory) {
        evc = _evc;
        whitelist = _whitelist;
    }

    function skim(uint256, address receiver) external view returns (uint256) {
        address receiverOwner = IEVC(evc).getAccountOwner(receiver);

        if (receiverOwner == address(0)) receiverOwner = receiver;

        require(IWhitelist(whitelist).isWalletAllowed(receiverOwner), "skim: receiver not whitelisted");

        return 0;
    }
}
