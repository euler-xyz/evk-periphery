// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib} from "./ScriptUtils.s.sol";

import {EVault} from "evk/EVault/EVault.sol";

interface IEVCUser {
    function EVC() external view returns (address);
}

contract DeploymentSanityCheck is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib, ExtraAddressesLib {
    function run() public view {
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(vm.readFile(vm.envString("CORE_ADDRESSES_PATH")));
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(vm.readFile(vm.envString("PERIPHERY_ADDRESSES_PATH")));
        ExtraAddresses memory extraAddresses =
            deserializeExtraAddresses(vm.readFile(vm.envString("EXTRA_ADDRESSES_PATH")));

        // Integrations are correct

        assert(IEVCUser(coreAddresses.balanceTracker).EVC() == coreAddresses.evc);

        assert(IEVCUser(peripheryAddresses.oracleRouterFactory).EVC() == coreAddresses.evc);

        assert(callWithTrailing(coreAddresses.eVaultImplementation, IEVCUser.EVC.selector) == coreAddresses.evc);
        assert(
            callWithTrailing(coreAddresses.eVaultImplementation, EVault.balanceTrackerAddress.selector)
                == coreAddresses.balanceTracker
        );
        assert(
            callWithTrailing(coreAddresses.eVaultImplementation, EVault.protocolConfigAddress.selector)
                == coreAddresses.protocolConfig
        );
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
