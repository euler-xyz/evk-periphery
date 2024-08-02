// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AllowList} from "./interfaces/AllowList.sol";
import {BaseHook} from "./BaseHook.sol";

contract HookTargetSuperStateAllowList is BaseHook {
    AllowList public immutable allowList;

    error E_notAllowed();

    constructor(AllowList _allowList) {
        allowList = _allowList;
    }

    function transfer(address to, uint256) external view returns (bool) {
        address msgSender = getAddressFromMsgData();

        // Check from
        if (!allowList.getPermission(msgSender).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(to).isAllowed) {
            revert E_notAllowed();
        }

        return true;
    }

    function transferFrom(address from, address to, uint256) external view returns (bool) {
        // Check from
        if (!allowList.getPermission(from).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(to).isAllowed) {
            revert E_notAllowed();
        }

        return true;
    }

    function deposit(uint256, address receiver) external view returns (uint256) {
        address msgSender = getAddressFromMsgData();

        // Check from
        if (!allowList.getPermission(msgSender).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(receiver).isAllowed) {
            revert E_notAllowed();
        }

        return 0;
    }

    function mint(uint256, address receiver) external view returns (uint256) {
        address msgSender = getAddressFromMsgData();

        // Check from
        if (!allowList.getPermission(msgSender).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(receiver).isAllowed) {
            revert E_notAllowed();
        }

        return 0;
    }

    function withdraw(uint256, address receiver, address owner) external view returns (uint256) {
        // Check from
        if (!allowList.getPermission(owner).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(receiver).isAllowed) {
            revert E_notAllowed();
        }

        return 0;
    }

    function redeem(uint256, address receiver, address owner) external view returns (uint256) {
        // Check from
        if (!allowList.getPermission(owner).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(receiver).isAllowed) {
            revert E_notAllowed();
        }

        return 0;
    }

    function skim(uint256, address receiver) external view returns (uint256) {
        address msgSender = getAddressFromMsgData();

        // Check from
        if (!allowList.getPermission(msgSender).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(receiver).isAllowed) {
            revert E_notAllowed();
        }

        return 0;
    }

    function liquidate(address violator, address collateral, uint256, uint256) external view {
        address msgSender = getAddressFromMsgData();
        // Check from
        if (!allowList.getPermission(violator).isAllowed) {
            revert E_notAllowed();
        }

        // Check to
        if (!allowList.getPermission(msgSender).isAllowed) {
            revert E_notAllowed();
        }
    }
}
