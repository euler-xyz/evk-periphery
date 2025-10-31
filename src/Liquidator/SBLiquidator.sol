// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {CustomLiquidatorBase} from "./CustomLiquidatorBase.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

interface ISBToken is IERC20 {
    function liquidationToken() external view returns (address);
    function liquidate(uint256 shares) external;
    function addLiquidator(address _account) external;
}

/// @title SBuidlLiquidator
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Implements specific liquidation logic for sBUIDL by Securitize.
contract SBuidlLiquidator is CustomLiquidatorBase {
    constructor(address evc, address owner, address[] memory _customLiquidationVaults)
        CustomLiquidatorBase(evc, owner, _customLiquidationVaults)
    {}

    /// @notice Liquidates the debt and executes the custom liquidation logic if the vault is set to use it.
    /// @param receiver The address to receive the collateral.
    /// @param liability The address of the liability vault.
    /// @param violator The address of the violator.
    /// @param collateral The address of the collateral vault.
    /// @param repayAssets The amount of assets to repay.
    /// @param minYieldBalance The minimum yield balance to receive.
    function _customLiquidation(
        address receiver,
        address liability,
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) internal override onlyOwner {
        IEVault collateralVault = IEVault(collateral);
        IEVault liabilityVault = IEVault(liability);
        ISBToken sbToken = ISBToken(collateralVault.asset());

        // Pass though liquidation
        uint256 collateralBalanceBefore = collateralVault.balanceOf(address(this));
        liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);
        uint256 collateralBalanceAfter = collateralVault.balanceOf(address(this));

        evc.call(
            liability, _msgSender(), 0, abi.encodeCall(liabilityVault.pullDebt, (type(uint256).max, address(this)))
        );

        // Redeem the seized collateral shares and liquidate them
        uint256 sbTokenBalance =
            collateralVault.redeem(collateralBalanceAfter - collateralBalanceBefore, address(this), address(this));
        sbToken.liquidate(sbTokenBalance);

        IERC20 sbLiquidationToken = IERC20(sbToken.liquidationToken());
        sbLiquidationToken.transfer(receiver, sbLiquidationToken.balanceOf(address(this)));
    }
}
