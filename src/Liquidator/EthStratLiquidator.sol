// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {ERC20Burnable} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title EthStratLiquidator
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Implements specific liquidation logic for EthStrat.
contract EthStratLiquidator is EVCUtil {
    /// @notice The address of the liability vault.
    IEVault public immutable liabilityVault;

    /// @notice The address of the collateral vault.
    IEVault public immutable collateralVault;

    /// @notice The address of the treasury which enables this contract as an operator.
    address public immutable treasury;

    constructor(address _liabilityVault, address _collateralVault, address _treasury)
        EVCUtil(IEVault(_liabilityVault).EVC())
    {
        liabilityVault = IEVault(_liabilityVault);
        collateralVault = IEVault(_collateralVault);
        treasury = _treasury;
    }

    /// @notice Liquidates the debt and executes the custom liquidation logic.
    /// @param violator The address of the violator.
    function liquidate(address violator) external {
        // Enable the liability vault as a controller
        evc.enableController(address(this), address(liabilityVault));

        // Pass though liquidation
        liabilityVault.liquidate(violator, address(collateralVault), type(uint256).max, 0);

        // Use treasury shares to repay the debt
        evc.call(
            address(liabilityVault),
            treasury,
            0,
            abi.encodeCall(liabilityVault.repayWithShares, (type(uint256).max, address(this)))
        );

        // Disable the liability vault as a controller
        liabilityVault.disableController();

        // Pay liquidation incentive
        collateralVault.transfer(_msgSender(), collateralVault.balanceOf(address(this)) / 100);

        // Redeem the rest of the seized shares and burn the assets
        ERC20Burnable stratToken = ERC20Burnable(collateralVault.asset());
        collateralVault.redeem(type(uint256).max, address(this), address(this));
        stratToken.burn(stratToken.balanceOf(address(this)));
    }
}
