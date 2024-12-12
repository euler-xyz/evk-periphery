// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

interface IWhitelist {
    function isWalletAllowed(address _user) external view returns (bool);
}

contract HookTargetWhitelistIdle is IHookTarget {
    address public immutable evc;
    address public immutable whitelist;
    error NotAuthorized();

    constructor(address _evc, address _whitelist) {
        evc = _evc;
        whitelist = _whitelist;
    }

    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    function deposit(uint256, address receiver) external view returns (uint256) {
        _authenticateAccountOwner(receiver);
        return 0;
    }

    function mint(uint256, address receiver) external view returns (uint256) {
        _authenticateAccountOwner(receiver);
        return 0;
    }

    function skim(uint256, address receiver) external view returns (uint256) {
        _authenticateAccountOwner(receiver);
        return 0;
    }

    function transfer(address to, uint256) external view returns (bool) {
        _authenticateAccountOwner(to);
        return true;
    }

    function transferFromMax(address, address to) external view returns (bool) {
        _authenticateAccountOwner(to);
        return true;
    }

    function transferFrom(address, address to, uint256) external view returns (bool) {
        _authenticateAccountOwner(to);
        return true;
    }

    function _authenticateAccountOwner(address account) internal view {
        address accountOwner = IEVC(evc).getAccountOwner(account);

        // if not registered yet, assume the account is the account owner
        if (accountOwner == address(0)) accountOwner = account;

        // if the account owner is not whitelisted, revert
        if (!IWhitelist(whitelist).isWalletAllowed(accountOwner)) revert NotAuthorized();
    }
}
