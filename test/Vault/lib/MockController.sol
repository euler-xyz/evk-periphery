// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IERC20} from "evk/EVault/IEVault.sol";

contract MockController {
    IEVC evc;
    bool revertOnCheck;
    address public checkZeroBalanceCollateral;
    uint256 checksBalanceResult;

    constructor(address _evc) {
        evc = IEVC(_evc);
    }

    function checkAccountStatus(address account, address[] calldata) public view returns (bytes4 magicValue) {
        if (revertOnCheck) revert("revert on check");

        if (checkZeroBalanceCollateral != address(0)) {
            if(IERC20(checkZeroBalanceCollateral).balanceOf(account) == 0) revert ("zero collateral balance");
            else revert ("non-zero collateral balance");
        }
        magicValue = this.checkAccountStatus.selector;
    }

    function mockBorrow() public {
        evc.requireAccountStatusCheck(msg.sender);
    }

    function disableController() public {
        evc.disableController(msg.sender);
    }

    function setRevertOnCheck(bool value) public {
        revertOnCheck = value;
    }

    function liquidate(address violator, address collateral, uint256 repayAssets, uint256) public {
        evc.controlCollateral(collateral, violator, 0, abi.encodeCall(IERC20.transfer, (msg.sender, repayAssets)));
    }

    function setCheckZeroBalanceCollateral(address newValue) public {
        checkZeroBalanceCollateral = newValue;
    }
}
