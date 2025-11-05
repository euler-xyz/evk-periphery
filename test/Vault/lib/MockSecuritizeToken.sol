// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IDSToken} from "../../../src/Vault/deployed/ERC4626EVCCollateralSecuritize.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";

contract MockSecuritizeToken is TestERC20, IDSToken {
    uint256 internal constant MOCK_COMPLIANCE_SERVICE_ID = 1;
    address complianceService;

    constructor(address _complianceService) TestERC20("Securitize mock token", "SEC", 18, false) {
        complianceService = _complianceService;
    }

    function getDSService(uint256) public view returns (address) {
        return complianceService;
    }

    function COMPLIANCE_SERVICE() public pure returns (uint256) {
        return MOCK_COMPLIANCE_SERVICE_ID;
    }
}
