// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {ScriptUtils, CoreInfoLib} from "./ScriptUtils.s.sol";

import {EVault} from "evk/EVault/EVault.sol";


interface IEVCUser {
    function EVC() external view returns (address);
}

contract DeploymentSanityCheck is ScriptUtils, CoreInfoLib {
    function run() public view {
        CoreInfo memory coreInfo = deserializeCoreInfo(vm.readFile(vm.envString("COREINFO_PATH")));


        // Integrations are correct

        assert(IEVCUser(coreInfo.balanceTracker).EVC() == coreInfo.evc);

        assert(IEVCUser(coreInfo.oracleRouterFactory).EVC() == coreInfo.evc);

        assert(callWithTrailing(coreInfo.eVaultImplementation, IEVCUser.EVC.selector) == coreInfo.evc);
        assert(callWithTrailing(coreInfo.eVaultImplementation, EVault.balanceTrackerAddress.selector) == coreInfo.balanceTracker);
        assert(callWithTrailing(coreInfo.eVaultImplementation, EVault.protocolConfigAddress.selector) == coreInfo.protocolConfig);
        // unfortunately no accessor for sequenceRegistry

        // FIXME: check perspectives, lenses, etc


        // FIXME: other things to check:
        //   * no duplicated contracts
        //   * is verified on etherscan
        //   * code exactly matches repo
    }

    function callWithTrailing(address target, bytes4 selector) internal view returns (address) {
        (bool success, bytes memory data) = target.staticcall(abi.encodePacked(selector, uint256(0), uint256(0)));
        assert(success);
        assert(data.length == 32);
        return abi.decode(data, (address));
    }
}
