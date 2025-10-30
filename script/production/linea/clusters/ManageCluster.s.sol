// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address internal constant wstETH = 0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F;
    address internal constant weETH = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant wrsETH = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
