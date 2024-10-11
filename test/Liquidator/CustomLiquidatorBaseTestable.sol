// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {CustomLiquidatorBase} from "../../src/Liquidator/CustomLiquidatorBase.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import {IEVault, IBorrowing} from "evk/EVault/IEVault.sol";

contract CustomLiquidatorBaseTestable is CustomLiquidatorBase {
    struct LiquidationParams {
        address receiver;
        address liability;
        address violator;
        address collateral;
        uint256 repayAssets;
        uint256 minYieldBalance;
    }

    LiquidationParams public liquidationParams;

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
        IEVault liabilityVault = IEVault(liability);
        IEVault collateralVault = IEVault(collateral);

        // Pass though liquidation
        liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);

        // Send colleral shares to receiver
        uint256 collateralBalance = collateralVault.balanceOf(address(this));
        collateralVault.transfer(receiver, collateralBalance);

        // Pull debt into liquidator
        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](1);

        uint256 debtAmount = liabilityVault.debtOf(address(this));
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(liabilityVault),
            onBehalfOfAccount: address(_msgSender()),
            value: 0,
            data: abi.encodeWithSelector(IBorrowing.pullDebt.selector, debtAmount, address(this))
        });

        evc.batch(batchItems);

        liquidationParams = LiquidationParams({
            receiver: receiver,
            liability: liability,
            violator: violator,
            collateral: collateral,
            repayAssets: repayAssets,
            minYieldBalance: minYieldBalance
        });
    }

    function getLiquidationParams() public view returns (LiquidationParams memory) {
        return liquidationParams;
    }
}
