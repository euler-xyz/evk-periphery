// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";
import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title FeeFlowControllerUtil
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that allows users to convert fees from multiple vaults and participate in the fee flow dutch
/// auction.
contract FeeFlowControllerUtil is EVCUtil, ReentrancyGuard {
    address public immutable feeFlowController;
    IERC20 public immutable paymentToken;

    constructor(address _feeFlowController) EVCUtil(FeeFlowController(_feeFlowController).EVC()) {
        feeFlowController = _feeFlowController;
        paymentToken = IERC20(address(FeeFlowController(feeFlowController).paymentToken()));
        SafeERC20.forceApprove(paymentToken, feeFlowController, type(uint256).max);
    }

    function buy(
        address[] calldata assets,
        address assetsReceiver,
        uint256 epochId,
        uint256 deadline,
        uint256 maxPaymentTokenAmount
    ) external nonReentrant returns (uint256) {
        uint256 paymentAmount = FeeFlowController(feeFlowController).getPrice();

        if (paymentAmount > maxPaymentTokenAmount) {
            revert FeeFlowController.MaxPaymentTokenAmountExceeded();
        }

        if (paymentAmount > 0) {
            SafeERC20.safeTransferFrom(paymentToken, _msgSender(), address(this), paymentAmount);
        }

        for (uint256 i = 0; i < assets.length; ++i) {
            IEVault(assets[i]).convertFees();
        }

        return
            FeeFlowController(feeFlowController).buy(assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
    }
}
