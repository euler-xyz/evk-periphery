// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EulerSavingsRate} from "evk/Synths/EulerSavingsRate.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

/// @title OFTGulper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that receives fee tokens, deposits them into an EulerSavingsRate vault, and triggers interest
/// smearing via gulp.
contract OFTGulper is Ownable, ILayerZeroComposer {
    using SafeERC20 for IERC20;

    /// @notice The EulerSavingsRate vault to which fees are deposited and gulped.
    EulerSavingsRate public immutable esr;

    /// @notice The ERC20 token used for fees.
    IERC20 public immutable feeToken;

    /// @notice Initializes the OFTGulper contract.
    /// @param owner_ The address that will be granted ownership of the contract.
    /// @param esr_ The address of the EulerSavingsRate vault.
    constructor(address owner_, address esr_) Ownable(owner_) {
        esr = EulerSavingsRate(esr_);
        feeToken = IERC20(esr.asset());
    }

    /// @notice Allows recovery of any ERC20 tokens or native currency sent to this contract.
    /// @param token The address of the token to recover. If address(0), the native currency is recovered.
    /// @param to The address to send the tokens to.
    /// @param amount The amount of tokens to recover.
    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success, "Native currency recovery failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Handles incoming composed messages from LayerZero and deposits any fee tokens held by this contract into
    /// the ESR vault, then calls gulp.
    /// @dev This function can be called at any time hence by anyone hence no need for additional checks or
    /// authentication.
    function lzCompose(address, bytes32, bytes calldata, address, bytes calldata) external payable override {
        uint256 balance = feeToken.balanceOf(address(this));
        if (balance == 0) return;

        feeToken.safeTransfer(address(esr), balance);
        esr.gulp();
    }
}
