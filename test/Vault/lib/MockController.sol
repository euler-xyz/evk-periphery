// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IERC20} from "evk/EVault/IEVault.sol";

contract MockController {
    IEVC evc;
    bool revertOnCheck;

    constructor(address _evc) {
        evc = IEVC(_evc);
    }

    function checkAccountStatus(address, address[] calldata) public view returns (bytes4 magicValue) {
        if (revertOnCheck) revert("revert on check");
        magicValue = this.checkAccountStatus.selector;
    }

    function setRevertOnCheck(bool value) public {
        revertOnCheck = value;
    }

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256) public {
        evc.controlCollateral(collateral, violator, 0, abi.encodeCall(IERC20.transfer, (msg.sender, repayAssets)));
    }
}
