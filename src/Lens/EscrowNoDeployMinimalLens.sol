// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IPerspective} from "../Perspectives/implementation/interfaces/IPerspective.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract EscrowNoDeployMinimalLens {
    struct Item {
        address vault;
        address asset;
    }

    constructor() {
    }

    function getData(address _perspective) public view returns (Item[] memory) {
        IPerspective perspective = IPerspective(_perspective);

        address[] memory verifiedArray = perspective.verifiedArray();
        Item[] memory items = new Item[](verifiedArray.length);

        for (uint256 i = 0; i < verifiedArray.length; i++) {
            IEVault vault = IEVault(verifiedArray[i]);
            address asset = vault.asset();
            items[i] = Item({vault: verifiedArray[i], asset: asset});
        }

        return items;
    }
}
