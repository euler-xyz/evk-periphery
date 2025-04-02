// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal constant slisBNB = 0xD9EdEba7f3580f5E22821A52fc1ba8508F4e34D0;
    address internal constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant lisUSD = 0x0782b6d8c4551B9760e74c0545a9bCD90bdc41E5;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}