// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EulerSavingsRate} from "evk/Synths/EulerSavingsRate.sol";
import {FeeCollectorUtil} from "./FeeCollectorUtil.sol";

/// @title FeeCollectorGulper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Collects and converts fees from multiple vaults, then deposits them into an EulerSavingsRate contract and
/// calls gulp.
contract FeeCollectorGulper is FeeCollectorUtil {
    using SafeERC20 for IERC20;

    /// @notice The EulerSavingsRate contract where collected fees are deposited and gulped.
    EulerSavingsRate public immutable esr;

    /// @notice Initializes the FeeCollectorGulper contract.
    /// @param _admin The address to be granted the DEFAULT_ADMIN_ROLE.
    /// @param _esr The address of the EulerSavingsRate contract to receive collected fees.
    constructor(address _admin, address _esr) FeeCollectorUtil(_admin, EulerSavingsRate(_esr).asset()) {
        esr = EulerSavingsRate(_esr);
    }

    /// @notice Collects and converts fees from all vaults in the list, then deposits them into the EulerSavingsRate
    /// contract and calls gulp.
    function collectFees() external virtual override {
        _convertAndRedeemFees();

        uint256 balance = feeToken.balanceOf(address(this));
        if (balance == 0) return;

        feeToken.safeTransfer(address(esr), balance);
        esr.gulp();
    }
}
