// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

contract UnknownPriceOracle {
    function getQuote(uint256, address, address) external pure returns (uint256) {
        return 0;
    }

    function getQuotes(uint256, address, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }
}
