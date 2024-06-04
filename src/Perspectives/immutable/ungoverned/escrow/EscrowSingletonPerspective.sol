// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {BasePerspective} from "../../../BasePerspective.sol";

contract EscrowSingletonPerspective is BasePerspective {
    mapping(address => address) public assetLookup;

    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    function name() public pure virtual override returns (string memory) {
        return "Immutable.Ungoverned.EscrowSingletonPerspective";
    }

    function perspectiveVerifyInternal(address vault, bool failEarly) internal override {
        // the vault must be deployed by recognized factory
        testProperty(vaultFactory.isProxy(vault), vault, ERROR__FACTORY, failEarly);

        // verify vault configuration at the factory level
        GenericFactory.ProxyConfig memory config = vaultFactory.getProxyConfig(vault);

        // escrow vaults must not be upgradeable
        testProperty(!config.upgradeable, vault, ERROR__UPGRADABILITY, failEarly);

        // there can be only one escrow vault per asset (singleton check)
        address asset = IEVault(vault).asset();
        testProperty(assetLookup[asset] == address(0), vault, ERROR__SINGLETON, failEarly);

        // escrow vaults must not be nested
        testProperty(!vaultFactory.isProxy(asset), vault, ERROR__NESTING, failEarly);

        // escrow vaults must not have an oracle or unit of account
        testProperty(IEVault(vault).oracle() == address(0), vault, ERROR__ORACLE, failEarly);
        testProperty(IEVault(vault).unitOfAccount() == address(0), vault, ERROR__UNIT_OF_ACCOUNT, failEarly);

        // verify vault configuration at the governance level.
        // escrow vaults must not have a governor admin, fee receiver, or interest rate model
        testProperty(IEVault(vault).governorAdmin() == address(0), vault, ERROR__GOVERNOR, failEarly);
        testProperty(IEVault(vault).feeReceiver() == address(0), vault, ERROR__FEE_RECEIVER, failEarly);
        testProperty(IEVault(vault).interestRateModel() == address(0), vault, ERROR__INTEREST_RATE_MODEL, failEarly);

        {
            // escrow vaults must not have supply or borrow caps
            (uint32 supplyCap, uint32 borrowCap) = IEVault(vault).caps();
            testProperty(supplyCap == 0, vault, ERROR__SUPPLY_CAP, failEarly);
            testProperty(borrowCap == 0, vault, ERROR__BORROW_CAP, failEarly);

            // escrow vaults must not have a hook target
            (address hookTarget, uint32 hookedOps) = IEVault(vault).hookConfig();
            testProperty(hookTarget == address(0), vault, ERROR__HOOK_TARGET, failEarly);

            // escrow vaults must have certain operations disabled
            testProperty(
                hookedOps
                    == (
                        OP_BORROW | OP_REPAY | OP_REPAY_WITH_SHARES | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE
                            | OP_TOUCH
                    ),
                vault,
                ERROR__HOOKED_OPS,
                failEarly
            );
        }

        // escrow vaults must not have any config flags set
        testProperty(IEVault(vault).configFlags() == 0, vault, ERROR__CONFIG_FLAGS, failEarly);

        // escrow vaults must neither have liquidation discount nor liquidation cool off time
        testProperty(IEVault(vault).maxLiquidationDiscount() == 0, vault, ERROR__LIQUIDATION_DISCOUNT, failEarly);
        testProperty(IEVault(vault).liquidationCoolOffTime() == 0, vault, ERROR__LIQUIDATION_COOL_OFF_TIME, failEarly);

        // escrow vaults must not have any collateral set up
        testProperty(IEVault(vault).LTVList().length == 0, vault, ERROR__LTV_LENGTH, failEarly);

        // store in mapping so that one escrow vault per asset can be achieved
        assetLookup[asset] = vault;
    }
}
