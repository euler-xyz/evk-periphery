// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import { GenericFactory } from "evk/GenericFactory/GenericFactory.sol";
import { EscrowSingletonPerspective } from "../Perspectives/deployed/EscrowSingletonPerspective.sol";
import { IEVault } from "evk/EVault/IEVault.sol";


contract EscrowFactory {
    GenericFactory public immutable vaultFactory;
    EscrowSingletonPerspective public immutable escrowPerspective;

    constructor(address vaultFactory_, address escrowPerspective_) {
        vaultFactory = GenericFactory(vaultFactory_);
        escrowPerspective = EscrowSingletonPerspective(escrowPerspective_);
    }


    function deploy(address asset) external returns (address) {
        IEVault vault = IEVault(vaultFactory.createProxy(
            address(0),
            false, // current perspective does not allow upgradeability.
            abi.encodePacked(asset, address(0), address(0))
        ));

        vault.setGovernorAdmin(address(0));
        escrowPerspective.perspectiveVerify(address(vault), true);

        return address(vault);
    }

    function getEscrowVault(address asset) external view returns (address) {
        return escrowPerspective.assetLookup(asset);   
    }
}