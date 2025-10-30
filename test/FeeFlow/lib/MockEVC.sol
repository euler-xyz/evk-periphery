// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MockEVC {
    address public onBehalfOfAccount;

    function setOnBehalfOfAccount(address account) external {
        onBehalfOfAccount = account;
    }

    function getCurrentOnBehalfOfAccount(address) external view returns (address, bool) {
        return (onBehalfOfAccount, false);
    }
}
