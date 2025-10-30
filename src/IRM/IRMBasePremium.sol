// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {AccessControl, IAccessControl, Context} from "openzeppelin-contracts/access/AccessControl.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMBasePremium
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Generic interest rate model where the interest rate is the sum of a base rate and a premium rate,
/// with the ability to override the premium rate for specific vaults.
contract IRMBasePremium is AccessControlEnumerable, EVCUtil, IIRM {
    /// @notice Struct for storing per-vault premium rate overrides.
    /// @param exists Whether an override exists for the vault.
    /// @param premiumRate The premium rate to use if override exists.
    struct RateOverride {
        bool exists;
        uint248 premiumRate;
    }

    /// @notice Role that allows updating the base rate and premium rates.
    bytes32 public constant RATE_ADMIN_ROLE = keccak256("RATE_ADMIN_ROLE");

    // corresponds to 1000% APY
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = 75986279153383989049;

    /// @notice The default base interest rate (applied to all vaults).
    uint128 public baseRate;

    /// @notice The default premium interest rate (applied to all vaults unless overridden).
    uint128 public premiumRate;

    /// @notice Mapping of vault address to its rate override (if any).
    mapping(address vault => RateOverride) public rateOverrides;

    /// @notice Emitted when the base interest rate is changed.
    /// @param newBaseRate The new base interest rate.
    event BaseRateSet(uint256 newBaseRate);

    /// @notice Emitted when the premium interest rate is changed.
    /// @param newPremiumRate The new premium interest rate.
    event PremiumRateSet(uint256 newPremiumRate);

    /// @notice Emitted when a rate override is set or cleared for a vault.
    /// @param vault The address of the vault.
    /// @param exists Whether the override exists.
    /// @param premiumRate The premium rate set for the override.
    event RateOverrideSet(address indexed vault, bool exists, uint256 premiumRate);

    /// @notice Deploy a new IRMBasePremium interest rate model.
    /// @param evc_ The address of the EVC.
    /// @param admin_ The address to be granted DEFAULT_ADMIN_ROLE.
    /// @param baseRate_ The default base interest rate.
    /// @param premiumRate_ The default premium interest rate.
    constructor(address evc_, address admin_, uint128 baseRate_, uint128 premiumRate_) EVCUtil(evc_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        baseRate = baseRate_;
        premiumRate = premiumRate_;
        emit BaseRateSet(baseRate_);
        emit PremiumRateSet(premiumRate_);
    }

    /// @notice Grants a role to an account. Only callable by EVC account owner.
    /// @param role The role to grant.
    /// @param account The address to grant the role to.
    function grantRole(bytes32 role, address account)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.grantRole(role, account);
    }

    /// @notice Revokes a role from an account. Only callable by EVC account owner.
    /// @param role The role to revoke.
    /// @param account The address to revoke the role from.
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.revokeRole(role, account);
    }

    /// @notice Renounces a role for the calling account. Only callable by EVC account owner.
    /// @param role The role to renounce.
    /// @param callerConfirmation The address of the caller (must match _msgSender()).
    function renounceRole(bytes32 role, address callerConfirmation)
        public
        virtual
        override (AccessControl, IAccessControl)
        onlyEVCAccountOwner
    {
        super.renounceRole(role, callerConfirmation);
    }

    /// @notice Set the default base interest rate.
    /// @param baseRate_ The new base interest rate.
    function setBaseRate(uint128 baseRate_) public onlyEVCAccountOwner onlyRole(RATE_ADMIN_ROLE) {
        baseRate = baseRate_;
        emit BaseRateSet(baseRate_);
    }

    /// @notice Set the default premium interest rate.
    /// @param premiumRate_ The new premium interest rate.
    function setPremiumRate(uint128 premiumRate_) public onlyEVCAccountOwner onlyRole(RATE_ADMIN_ROLE) {
        premiumRate = premiumRate_;
        emit PremiumRateSet(premiumRate_);
    }

    /// @notice Set or clear a premium rate override for a specific vault.
    /// @param vault The address of the vault.
    /// @param exists Whether the override should exist (true to set, false to clear).
    /// @param premiumRate_ The premium rate to use if override is enabled.
    function setRateOverride(address vault, bool exists, uint128 premiumRate_)
        public
        onlyEVCAccountOwner
        onlyRole(RATE_ADMIN_ROLE)
    {
        rateOverrides[vault] = RateOverride({exists: exists, premiumRate: premiumRate_});
        emit RateOverrideSet(vault, exists, premiumRate_);
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows)
        external
        view
        override
        returns (uint256)
    {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();

        return computeInterestRateInternal(vault, cash, borrows);
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows)
        external
        view
        override
        returns (uint256)
    {
        return computeInterestRateInternal(vault, cash, borrows);
    }

    /// @notice Internal function to compute the interest rate for a vault.
    /// @param vault The address of the vault.
    /// @return The computed interest rate for the vault.
    function computeInterestRateInternal(address vault, uint256, uint256) internal view returns (uint256) {
        RateOverride memory rateOverride = rateOverrides[vault];
        uint256 rate = rateOverride.exists
            ? uint256(baseRate) + uint256(rateOverride.premiumRate)
            : uint256(baseRate) + uint256(premiumRate);

        return rate > MAX_ALLOWED_INTEREST_RATE ? MAX_ALLOWED_INTEREST_RATE : rate;
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @return msgSender The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address msgSender) {
        return EVCUtil._msgSender();
    }
}
