// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EulerSavingsRate} from "evk/Synths/EulerSavingsRate.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {FeeCollectorUtil} from "../Util/FeeCollectorUtil.sol";

/// @title OFTFeeCollectorGulper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Collects and converts fees from multiple vaults, then deposits them into an EulerSavingsRate contract and
/// calls gulp. Additionally, it implements the LayerZero composer interface to receive fee tokens cross-chain in order
/// to deposit them into the EulerSavingsRate vault and trigger interest smearing via gulp.
contract OFTFeeCollectorGulper is FeeCollectorUtil, ILayerZeroComposer {
    using SafeERC20 for IERC20;

    /// @notice The EulerSavingsRate contract where collected fees are deposited and gulped.
    EulerSavingsRate public immutable esr;

    /// @notice Initializes the OFTFeeCollectorGulper contract.
    /// @param _evc The address of the EVC contract
    /// @param _admin The address to be granted the DEFAULT_ADMIN_ROLE.
    /// @param _esr The address of the EulerSavingsRate contract to receive collected fees.
    constructor(address _evc, address _admin, address _esr)
        FeeCollectorUtil(_evc, _admin, EulerSavingsRate(_esr).asset())
    {
        esr = EulerSavingsRate(_esr);
    }

    /// @notice Collects and converts fees from all vaults in the list, then deposits them into the EulerSavingsRate
    /// contract and calls gulp.
    function collectFees() external virtual override {
        _convertAndRedeemFees();
        _transferAndGulp();
    }

    /// @notice Handles incoming composed messages from LayerZero and deposits any fee tokens held by this contract into
    /// the ESR vault, then calls gulp.
    /// @dev This function can be called at any time hence by anyone hence no need for additional checks or
    /// authentication.
    function lzCompose(address, bytes32, bytes calldata, address, bytes calldata) external payable override {
        _transferAndGulp();
    }

    /// @dev Internal function to transfer fees to the ESR vault and trigger interest smearing via gulp.
    function _transferAndGulp() internal {
        uint256 balance = feeToken.balanceOf(address(this));
        if (balance == 0) return;

        feeToken.safeTransfer(address(esr), balance);
        esr.gulp();
    }
}
