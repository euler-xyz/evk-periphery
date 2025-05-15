# HookTargetAccessControlKeyring

## Overview

The `HookTargetAccessControlKeyring` is a specialized hook target contract that combines selector-based access control with keyring credential verification. This contract enables vault operators to restrict access to critical vault operations, ensuring only authorized users with valid credentials can perform operations on vaults.

## Purpose

The primary purpose of the `HookTargetAccessControlKeyring` is to provide a robust, dual-layer authentication system for EVK vaults:

1. **Selector-based access control** - Allows specific addresses to be whitelisted for particular function selectors
2. **Keyring credential verification** - Requires users to possess valid credentials according to a specified policy

This approach creates a flexible security model where:
- Privileged addresses can bypass credential checks when needed
- Regular users must possess valid credentials to interact with the vault
- Different types of operations can have tailored access requirements

## Components

The `HookTargetAccessControlKeyring` integrates several components:

- **BaseHookTarget** - Provides the foundation for intercepting vault operations
- **SelectorAccessControl** - Provides role-based access control mapped to function selectors
- **IKeyringCredentials** - External interface for credential verification

## Authentication Mechanism

The contract implements a sophisticated authentication workflow through the `_authenticateCallerAndAccount` function:

1. **Initial Role Check**:
   - First, check if the caller has either the `WILD_CARD` role or a specific role for the current function selector
   - If yes, bypass the keyring credential check entirely

2. **Caller Credential Check**:
   - Determine the EVC owner of the calling account
   - If no owner is registered, assume the caller itself is the owner
   - Verify the owner has valid credentials according to the specified policy ID

3. **Account Credential Check**:
   - Only performed if the account being operated on has a different EVC owner than the caller
   - Determine the EVC owner of the account being operated on
   - If no owner is registered, assume the account itself is the owner
   - Verify this owner also has valid credentials according to the policy ID

4. **Optimization**:
   - If the caller and the account being operated on share the same EVC owner, only one credential check is performed

This mechanism ensures that both the entity initiating the operation and the entity being affected by it (if different) have proper authorization.

## Hooked Operations

The contract intercepts and applies its authentication mechanism to the following vault operations:

1. **Asset Deposit/Mint Operations**:
   - `deposit(uint256, address receiver)`
   - `mint(uint256, address receiver)`
   - `skim(uint256, address receiver)`

2. **Asset Withdrawal/Redemption Operations**:
   - `withdraw(uint256, address, address owner)`
   - `redeem(uint256, address, address owner)`

3. **Borrowing/Repayment Operations**:
   - `borrow(uint256, address receiver)`
   - `repay(uint256, address receiver)`
   - `repayWithShares(uint256, address receiver)`
   - `pullDebt(uint256, address from)`

For each of these operations, the contract authenticates both the caller and the relevant account parameter (receiver or owner).

### Fallback Mechanism

The contract implements a fallback function that provides a catch-all authentication mechanism for any hooked operations that are not explicitly intercepted by the above functions.

When a hooked operation is called that doesn't match any of the explicitly defined functions, the fallback function:
- Authenticates only the caller using the `_authenticateCaller` function
- Applies the same role-based access control rules (WILD_CARD and selector-specific roles)
- Does not perform keyring credential checks on any additional accounts

## Usage Patterns

### Installation Pattern

To use this hook target:

1. Deploy an instance of `HookTargetAccessControlKeyring`, specifying:
   - EVC address
   - Admin address
   - EVault factory address
   - Keyring contract address
   - Policy ID

2. Grant roles to addresses that should bypass credential checks

3. Install the hook target on the desired vault(s) and configure which operations should be hooked

## Example Scenario

A vault operator could use this hook target to create a vault cluster where:
- Only users with valid credentials can perform operations on the vaults
- Specific addresses (like chosen liquidators) are whitelisted to bypass credential checks

To achieve the above, the following operations should be hooked: `OP_DEPOSIT`, `OP_MINT`, `OP_WITHDRAW`, `OP_REDEEM`, `OP_SKIM`, `OP_BORROW`, `OP_REPAY`, `OP_REPAY_WITH_SHARES`, `OP_PULL_DEBT`, `OP_LIQUIDATE` and `OP_FLASHLOAN`.

The liquidators should be granted the `WILD_CARD` role so that they can liquidate and close the position without needing to obtain a Keyring credential.