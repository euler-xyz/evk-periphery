// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant USDC = 0x83235A46726803c1980A28cE283D90f6281b2530;
    address internal constant USDT0 = 0xcEdc4054676d39716AEF0347b319487989797119;
    address internal constant sUSDS = 0x67D6FeeC2936e3F014a087c442FdC4774C1C30C4;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
