// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import {IEVault, IERC20, IBorrowing} from "evk/EVault/IEVault.sol";

/// @dev Liquidator should enable this contract as an operator
abstract contract CustomLiquidatorBase is EVCUtil, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private customLiquidationVaults;

    error NOT_EVC();

    event CustomLiquidationVaultSet(address indexed vault, bool enabled);

    constructor(address _evc, address[] memory _customLiquidationVaults) EVCUtil(_evc) Ownable(_msgSender()) {
        for (uint256 i = 0; i < _customLiquidationVaults.length; i++) {
            customLiquidationVaults.add(_customLiquidationVaults[i]);
            emit CustomLiquidationVaultSet(_customLiquidationVaults[i], true);
        }
    }

    function isCustomLiquidationVault(address vault) public view returns (bool) {
        return customLiquidationVaults.contains(vault);
    }

    function getCustomLiquidationVaults() public view returns (address[] memory) {
        return customLiquidationVaults.values();
    }

    function setCustomLiquidationVault(address vault, bool enabled) public onlyOwner {
        if (enabled) {
            customLiquidationVaults.add(vault);
        } else {
            customLiquidationVaults.remove(vault);
        }
        emit CustomLiquidationVaultSet(vault, enabled);
    }

    function liquidate(
        address receiver,
        address liability,
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) public {
        // Enter deferred liquidity checks
        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](1);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(this),
            onBehalfOfAccount: address(_msgSender()),
            value: 0,
            data: abi.encodeWithSelector(
                this.deferredLiquidate.selector, receiver, liability, violator, collateral, repayAssets, minYieldBalance
            )
        });
        evc.batch(batchItems);
    }

    function deferredLiquidate(
        address receiver,
        address liability,
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) public {
        if (msg.sender != address(evc)) {
            revert NOT_EVC();
        }

        IEVault liabilityVault = IEVault(liability);
        IEVault collateralVault = IEVault(collateral);

        evc.enableController(address(this), address(liabilityVault));

        if (isCustomLiquidationVault(collateral)) {
            // Execute custom liquidation logic
            _customLiquidation(receiver, liability, violator, collateral, repayAssets, minYieldBalance);
        } else {
            // Pass through liquidation
            liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);
            // If not a custom liquidation vault, send the collateral to the receiver and push the debt as an operator
            IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](2);

            uint256 debtAmount = liabilityVault.debtOf(address(this));
            uint256 collateralAmount = collateralVault.balanceOf(address(this));

            // Pull the debt from this contract into the liquidator
            batchItems[0] = IEVC.BatchItem({
                targetContract: address(liabilityVault),
                onBehalfOfAccount: address(_msgSender()),
                value: 0,
                data: abi.encodeWithSelector(IBorrowing.pullDebt.selector, debtAmount, address(this))
            });

            // Send the collateral to the receiver
            batchItems[1] = IEVC.BatchItem({
                targetContract: address(collateralVault),
                onBehalfOfAccount: address(this),
                value: 0,
                data: abi.encodeWithSelector(IERC20.transfer.selector, receiver, collateralAmount)
            });

            evc.batch(batchItems);
        }

        evc.disableController(address(liabilityVault));
    }

    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }

    function _customLiquidation(
        address receiver,
        address liability,
        address violator,
        address collateral,
        uint256 repayAssets,
        uint256 minYieldBalance
    ) internal virtual;
}
