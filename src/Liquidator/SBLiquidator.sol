// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {IEVault, IERC20} from "evk/EVault/IEVault.sol";


interface ISBToken is IERC20 {
    function liquidationToken() external view returns (address);
    function liquidate(uint256 shares) external;
}

contract SBLiquidator is EVCUtil {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private redeemVaults;

    constructor(address _evc, address[] memory _redeemVaults) EVCUtil(_evc) {
        for (uint256 i = 0; i < _redeemVaults.length; i++) {
            redeemVaults.add(_redeemVaults[i]);
        }
    }

    /// @notice Checks if a vault is in the set of vaults that should be redeemed
    /// @param vault The address of the vault to check
    /// @return bool True if the vault should be redeemed, false otherwise
    function isRedeemVault(address vault) public view returns (bool) {
        return redeemVaults.contains(vault);
    }

    /// @notice Gets all redeem vaults
    /// @return address[] memory The addresses of the redeem vaults
    function getRedeemVaults() public view returns (address[] memory) {
        return redeemVaults.values();
    }

    /// @notice Liquidates a violator's position by repaying the debt and withdrawing the collateral.
    /// @dev TODO determine if below is safe or its better to push the debt as an operator
    /// @dev It is expected that the caller pulls the debt in an EVC batch to leave this contract healthy after the transaction 
    /// @param violator The address of the violator.
    /// @param collateral The address of the collateral.
    /// @param repayAssets The amount of assets to repay.
    /// @param minYieldBalance The minimum amount of yield balance to withdraw.
    function liquidate(address receiver, address liability, address violator, address collateral, uint256 repayAssets, uint256 minYieldBalance) public {
        IEVault liabilityVault = IEVault(liability);

        // Pass through liquidation
        liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);

        if(isRedeemVault(collateral)) { // If collateral is a redeem vault, redeem the collateral
            IEVault collateralVault = IEVault(collateral);
            // Redeem the entire collateral balance in this account
            uint256 collateralBalance = collateralVault.balanceOf(address(this));
            collateralVault.redeem(collateralBalance, address(this), address(this));

            ISBToken sbToken = ISBToken(collateralVault.asset());
            uint256 sbTokenBalance = sbToken.balanceOf(address(this));

            // Liquidate the SB token to the liquidation token
            sbToken.liquidate(sbTokenBalance);

            // Send the liquidation token to the receiver
            IERC20 sbLiquidationToken = IERC20(sbToken.liquidationToken());
            sbLiquidationToken.transfer(receiver, sbLiquidationToken.balanceOf(address(this)));

        } else { // If not a redeem vault, send the collateral to the receiver
            // Send the collateral to the receiver
            IERC20 collateralToken = IERC20(collateral);
            collateralToken.transfer(receiver, collateralToken.balanceOf(address(this)));
        }

        
    }

}
