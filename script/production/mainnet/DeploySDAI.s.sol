// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {EVaultDeployer} from "../../07_EVault.s.sol";
import {SnapshotRegistry} from "../../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

contract DeploySDAI is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib {
    address internal constant sDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function run() public returns (address escrowVaultSDAI) {
        address deployerAddress = getDeployer();
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(getInputConfig("CoreAddresses.json"));
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(getInputConfig("PeripheryAddresses.json"));

        // add sDAI to the external vault registry
        startBroadcast();
        SnapshotRegistry(peripheryAddresses.externalVaultRegistry).add(sDAI, sDAI, DAI);
        stopBroadcast();

        // deploy the sDAI escrow vault
        {
            EVaultDeployer deployer = new EVaultDeployer();
            (, escrowVaultSDAI) =
                deployer.deploy(address(0), false, coreAddresses.eVaultFactory, true, sDAI, address(0), address(0));
        }

        // configure the sDAI escrow vault and verify it by the escrow perspective
        startBroadcast();
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);
        items[0].targetContract = escrowVaultSDAI;
        items[0].onBehalfOfAccount = deployerAddress;
        items[0].data = abi.encodeCall(IEVault(escrowVaultSDAI).setHookConfig, (address(0), 0));

        items[1].targetContract = escrowVaultSDAI;
        items[1].onBehalfOfAccount = deployerAddress;
        items[1].data = abi.encodeCall(IEVault(escrowVaultSDAI).setGovernorAdmin, (address(0)));

        items[2].targetContract = peripheryAddresses.escrowedCollateralPerspective;
        items[2].onBehalfOfAccount = deployerAddress;
        items[2].data = abi.encodeCall(BasePerspective.perspectiveVerify, (escrowVaultSDAI, true));

        IEVC(coreAddresses.evc).batch(items);
        stopBroadcast();
    }
}
