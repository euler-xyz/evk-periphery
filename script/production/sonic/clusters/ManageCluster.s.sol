// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b;
    address internal constant USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address internal constant scETH = 0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812;
    address internal constant scUSD = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;
    address internal constant wstkscETH = 0xE8a41c62BB4d5863C6eadC96792cFE90A1f37C47;
    address internal constant wstkscUSD = 0x9fb76f7ce5FCeAA2C42887ff441D46095E494206;
    address internal constant wS = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address internal constant stS = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955;
    address internal constant sS = 0x6BA47940f738175d3F8C22Aa8EE8606eaAe45eb2;
    address internal constant wOS = 0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1;
    address internal constant solvBTC = 0x541FD749419CA806a8bc7da8ac23D346f2dF8B77;
    address internal constant solvBTC_BBN = 0xCC0966D8418d412c599A6421b760a847eB169A8c;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
