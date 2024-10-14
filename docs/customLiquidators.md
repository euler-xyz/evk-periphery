# Custom Liquidators

By using the `HookTargetAccessControl` liquidation can be shielded to make it only callable by specific addresses.
Using a custom liquidator different liquidation logic can be implemented.

## CustomLiquidatorBase

The owner of the contract can set which collateral vaults should follow a custom liquidation logic by calling `setCustomLiquidationVault`. The custom liquidation logic is implemented in the `_customLiquidation` function. Liquidators should call the custom liquidator contract instead of the vault itself when it is enabled. Additionally liquidators should enable the custom liquidator contract as an operator to allow it to pull the debt into their account on their behalf.

## SBLiquidator

The SBLiquidator is an example implementation of a custom liquidator. It is build to be used with sBUIDL by securitize. Instead of transferring collateral vault shares to the liquidator, the liquidator will receive USDC which is automatically redeemed from the sBUIDL contract.