// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Swapper} from "./Swapper.sol";
import {ISwapper} from "./ISwapper.sol";

/// @title SwapperOwnableNonTransferrable
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Untrusted helper contract for EVK for performing swaps and swaps to repay. Ownable version.
/// @dev Ownership is not transferrable not to violate external whitelistings
contract SwapperOwnable is Swapper, Ownable {
    constructor(address owner, address uniswapRouterV2, address uniswapRouterV3)
        Ownable(owner)
        Swapper(uniswapRouterV2, uniswapRouterV3)
    {}

    /// @inheritdoc ISwapper
    function swap(SwapParams memory params) public override onlyOwner {
        super.swap(params);
    }

    /// @inheritdoc ISwapper
    function repay(address token, address vault, uint256 repayAmount, address account) public override onlyOwner {
        super.repay(token, vault, repayAmount, account);
    }

    /// @inheritdoc ISwapper
    function repayAndDeposit(address token, address vault, uint256 repayAmount, address account) public override onlyOwner {
        super.repayAndDeposit(token, vault, repayAmount, account);
    }

    /// @inheritdoc ISwapper
    function deposit(address token, address vault, uint256 amountMin, address account) public override onlyOwner {
        super.deposit(token, vault, amountMin, account);
    }

    /// @inheritdoc ISwapper
    function sweep(address token, uint256 amountMin, address to) public override onlyOwner {
        super.sweep(token, amountMin, to);
    }

    /// @inheritdoc ISwapper
    function multicall(bytes[] memory calls) public override onlyOwner {
        super.multicall(calls);
    }

    function transferOwnership(address) public pure override {
        revert("ownership not transferrable");
    }
}
