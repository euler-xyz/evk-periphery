// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {EscrowSingletonPerspective} from "../Perspectives/deployed/EscrowSingletonPerspective.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract EscrowFactory {
    constructor(address vaultFactory_, address escrowPerspective_, address _asset) {
        GenericFactory vaultFactory = GenericFactory(vaultFactory_);
        EscrowSingletonPerspective escrowPerspective = EscrowSingletonPerspective(escrowPerspective_);

        IEVault vault = IEVault(
            vaultFactory.createProxy(
                address(0),
                true, // current perspective requires.
                abi.encodePacked(_asset, address(0), address(0))
            )
        );

        vault.setHookConfig(address(0), uint32(0));
        vault.setGovernorAdmin(address(0));
        escrowPerspective.perspectiveVerify(address(vault), true);

        selfdestruct(payable(address(0)));
    }
}
