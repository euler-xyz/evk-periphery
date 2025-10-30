// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "evk/EVault/IEVault.sol";

/// @title PendleLPWrapper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Simple contract used to wrap/unwrap Pendle LP tokens it holds
/// @dev This contract is untrusted helper for the Swapper contract
contract PendleLPWrapperTool {
    function wrap(address lpToken, address wrapper, address receiver) public {
        uint256 balance = IERC20(lpToken).balanceOf(address(this));
        IERC20(lpToken).approve(wrapper, type(uint256).max);
        IPendleLPWrapper(wrapper).wrap(receiver, balance);
    }

    function unwrap(address wrapper, address receiver) public {
        uint256 balance = IERC20(wrapper).balanceOf(address(this));
        IPendleLPWrapper(wrapper).unwrap(receiver, balance);
    }
}

interface IPendleLPWrapper is IERC20 {
    function wrap(address receiver, uint256 netLpIn) external;
    function unwrap(address receiver, uint256 netWrapIn) external;
}
