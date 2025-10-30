// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

contract MockController {
    bool revertOnCheck;

    function checkAccountStatus(address, address[] calldata) public view returns (bytes4 magicValue) {
        if (revertOnCheck) revert("revert on check");
        magicValue = this.checkAccountStatus.selector;
    }

    function setRevertOnCheck(bool value) public {
        revertOnCheck = value;
    }
}
