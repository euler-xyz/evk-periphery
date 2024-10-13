// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {CustomLiquidatorBase} from "./CustomLiquidatorBase.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IBorrowing, IERC4626} from "evk/EVault/IEVault.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";

interface ISBToken is IERC20 {
    function liquidationToken() external view returns (address);
    function liquidate(uint256 shares) external;
    function addLiquidator(address _account) external;
}

contract SBuidlLiquidator is CustomLiquidatorBase {
    constructor(address _evc, address[] memory _customLiquidationVaults)
        CustomLiquidatorBase(_evc, _customLiquidationVaults)
    {}

    function _customLiquidation(
        address receiver,
        address liability,
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) internal override {
        IEVault collateralVault = IEVault(collateral);
        IEVault liabilityVault = IEVault(liability);
        ISBToken sbToken = ISBToken(collateralVault.asset());

        // Pass though liquidation
        liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);

        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](2);

        uint256 debtAmount = liabilityVault.debtOf(address(this));

        batchItems[0] = IEVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: address(_msgSender()),
            value: 0,
            data: abi.encodeWithSelector(IBorrowing.pullDebt.selector, debtAmount, address(this))
        });

        // Redeem the entire collateral balance in this account
        uint256 collateralBalance = collateralVault.balanceOf(address(this));

        batchItems[1] = IEVC.BatchItem({
            targetContract: address(collateralVault),
            onBehalfOfAccount: address(address(this)),
            value: 0,
            data: abi.encodeWithSelector(IERC4626.redeem.selector, collateralBalance, address(this), address(this))
        });

        evc.batch(batchItems);

        uint256 sbTokenBalance = sbToken.balanceOf(address(this));
        sbToken.liquidate(sbTokenBalance);

        IERC20 sbLiquidationToken = IERC20(sbToken.liquidationToken());
        sbLiquidationToken.transfer(receiver, sbLiquidationToken.balanceOf(address(this)));
    }
}
