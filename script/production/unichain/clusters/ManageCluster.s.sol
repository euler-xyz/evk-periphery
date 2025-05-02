// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant wstETH = 0xc02fE7317D4eb8753a02c35fe019786854A92001;
    address internal constant weETH = 0x7DCC39B4d1C53CB31e1aBc0e358b43987FEF80f7;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant rsETH = 0xc3eACf0612346366Db554C991D7858716db09f58;
    address internal constant USDC = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
    address internal constant USDT0 = 0x9151434b16b9763660705744891fA906F660EcC5;
    address internal constant WBTC = 0x927B51f251480a681271180DA4de28D44EC4AfB8;
    address internal constant UNI = 0x8f187aA05619a017077f5308904739877ce9eA21;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
