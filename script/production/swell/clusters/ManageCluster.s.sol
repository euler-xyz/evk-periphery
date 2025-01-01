// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant wstETH = 0x7c98E0779EB5924b3ba8cE3B17648539ed5b0Ecc;
    address internal constant weETH = 0xA6cB988942610f6731e664379D15fFcfBf282b44;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant rsETH = 0xc3eACf0612346366Db554C991D7858716db09f58;
    address internal constant swETH = 0x09341022ea237a4DB1644DE7CCf8FA0e489D85B7;
    address internal constant rswETH = 0x18d33689AE5d02649a859A1CF16c9f0563975258;
    address internal constant pzETH = 0x9cb41CD74D01ae4b4f640EC40f7A60cA1bCF83E7;
    address internal constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address internal constant swBTC = 0x1cf7b5f266A0F39d6f9408B90340E3E71dF8BF7B;
    address internal constant ENA = 0x58538e6A46E07434d7E7375Bc268D3cb839C0133;
    address internal constant SWELL = 0x2826D136F5630adA89C1678b64A61620Aab77Aea;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
