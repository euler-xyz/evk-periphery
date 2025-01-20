// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {EVCUtil} from "evc/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @dev Liquidator should enable this contract as an operator
/// @title CustomLiquidatorBase
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract is used to implement custom liquidation logic for specific collateral vaults.
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

    /// @notice Checks if a given vault is set to use custom liquidation logic.
    /// @param vault The address of the vault to check.
    /// @return bool True if the vault is set to use custom liquidation logic, false otherwise.
    function isCustomLiquidationVault(address vault) public view returns (bool) {
        return customLiquidationVaults.contains(vault);
    }

    /// @notice Returns all vaults that use custom liquidation logic.
    /// @return address[] memory An array of addresses of the vaults that use custom liquidation logic.
    function getCustomLiquidationVaults() public view returns (address[] memory) {
        return customLiquidationVaults.values();
    }

    /// @notice Sets a vault to use custom liquidation logic.
    /// @param vault The address of the vault to set.
    /// @param enabled True if the vault should use custom liquidation logic, false otherwise.
    function setCustomLiquidationVault(address vault, bool enabled) public onlyEVCAccountOwner onlyOwner {
        if (enabled) {
            customLiquidationVaults.add(vault);
        } else {
            customLiquidationVaults.remove(vault);
        }
        emit CustomLiquidationVaultSet(vault, enabled);
    }

    /// @notice Liquidates the debt and executes the custom liquidation logic if the vault is set to use it.
    /// @param receiver The address to receive the collateral.
    /// @param liability The address of the liability vault.
    /// @param violator The address of the violator.
    /// @param collateral The address of the collateral vault.
    /// @param repayAssets The amount of assets to repay.
    /// @param minYieldBalance The minimum yield balance to receive.
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
            evc.call(
                liability, _msgSender(), 0, abi.encodeCall(liabilityVault.pullDebt, (type(uint256).max, address(this)))
            );

            // Send the collateral to the receiver
            collateralVault.transferFromMax(address(this), receiver);
        }

        liabilityVault.disableController();
    }

    /// @notice Overrides the default msgSender to use the EVCUtil msgSender.
    /// @return address The EVC authenticated sender.
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }

    /// @notice Custom liquidation logic.
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
    ) internal virtual;
}
