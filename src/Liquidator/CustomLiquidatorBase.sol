// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @dev Liquidator should enable this contract as an operator
abstract contract CustomLiquidatorBase is EVCUtil, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private customLiquidationVaults;

    event CustomLiquidationVaultSet(address indexed vault, bool enabled);

    constructor(address evc, address owner, address[] memory _customLiquidationVaults) EVCUtil(evc) Ownable(owner) {
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

    function setCustomLiquidationVault(address vault, bool enabled) public onlyEVCAccountOwner onlyOwner {
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
    ) public callThroughEVC {
        IEVault liabilityVault = IEVault(liability);
        IEVault collateralVault = IEVault(collateral);

        evc.enableController(address(this), liability);

        if (isCustomLiquidationVault(collateral)) {
            // Execute custom liquidation logic
            _customLiquidation(receiver, liability, violator, collateral, repayAssets, minYieldBalance);
        } else {
            // Pass through liquidation
            liabilityVault.liquidate(violator, collateral, repayAssets, minYieldBalance);
            
            // Pull the debt from this contract into the liquidator
            evc.call(liability, _msgSender(), 0, abi.encodeCall(liabilityVault.pullDebt, (type(uint256).max, address(this))));

            // Send the collateral to the receiver
            collateralVault.transferFromMax(address(this), receiver);
        }

        evc.disableController(liability);
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
