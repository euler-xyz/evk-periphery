// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MockESR {
    bool public gulpWasCalled;
    address public asset;

    constructor(address _asset) {
        asset = _asset;
    }

    function gulp() public {
        gulpWasCalled = true;
    }
}
