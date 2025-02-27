// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title EscrowedCollateralPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has properties of an escrow vault. It allows only one escrow vault
/// per asset.
contract EscrowedCollateralPerspective is BasePerspective {
    /// @notice A mapping to look up the vault associated with a given asset.
    mapping(address => address) public singletonLookup;

    /// @notice Creates a new EscrowedCollateralPerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Escrowed Collateral Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), ERROR__FACTORY);

        // escrow vaults must be upgradeable
        testProperty(vaultFactory.getProxyConfig(vault).upgradeable, ERROR__UPGRADABILITY);

        // escrow vaults must not be nested
        address asset = IEVault(vault).asset();
        testProperty(!vaultFactory.isProxy(asset), ERROR__NESTING);

        // escrow vaults must not have an oracle or unit of account
        testProperty(IEVault(vault).oracle() == address(0), ERROR__ORACLE_INVALID_ROUTER);
        testProperty(IEVault(vault).unitOfAccount() == address(0), ERROR__UNIT_OF_ACCOUNT);

        // escrow vaults must be singletons
        testProperty(singletonLookup[asset] == address(0), ERROR__SINGLETON);

        // verify vault configuration at the governance level.
        // escrow vaults must not have a governor admin, fee receiver, or interest rate model
        testProperty(IEVault(vault).governorAdmin() == address(0), ERROR__GOVERNOR);
        testProperty(IEVault(vault).feeReceiver() == address(0), ERROR__FEE_RECEIVER);
        testProperty(IEVault(vault).interestRateModel() == address(0), ERROR__INTEREST_RATE_MODEL);

        {
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();

            // escrow vaults must not have supply cap
            testProperty(supplyCap == 0, ERROR__SUPPLY_CAP);

            // escrow vaults must not have borrow cap
            testProperty(borrowCap == 0, ERROR__BORROW_CAP);

            // escrow vaults must not have a hook target nor any operations disabled
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), ERROR__HOOK_TARGET);
            testProperty(hookedOps == 0, ERROR__HOOKED_OPS);
        }

        // escrow vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, ERROR__CONFIG_FLAGS);

        // escrow vaults must neither have liquidation discount nor liquidation cool off time
        testProperty(IEVault(vault).maxLiquidationDiscount() == 0, ERROR__LIQUIDATION_DISCOUNT);
        testProperty(IEVault(vault).liquidationCoolOffTime() == 0, ERROR__LIQUIDATION_COOL_OFF_TIME);

        // escrow vaults must not have any collateral set up
        testProperty(IEVault(vault).LTVList().length == 0, ERROR__LTV_COLLATERAL_CONFIG_LENGTH);

        // store in mapping so that there's only one escrow vault per asset
        if (singletonLookup[asset] == address(0)) {
            singletonLookup[asset] = vault;
        }
    }
}
