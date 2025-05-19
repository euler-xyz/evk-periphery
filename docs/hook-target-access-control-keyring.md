# HookTargetAccessControlKeyring

## Overview

The `HookTargetAccessControlKeyring` is a specialized hook target contract that combines selector-based access control with Keyring credential verification. This contract enables vault operators to restrict access to critical vault operations, ensuring only authorized users with valid credentials can perform operations on vaults.

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
   - If yes, bypass the Keyring credential check entirely

2. **Caller Credential Check**:
   - Determine the EVC owner of the calling account
   - If no owner is registered, assume the caller itself is the owner
   - If the owner lacks valid Keyring credential according to the policy ID:
     - Check if they have the `PRIVILEGED_ACCOUNT_ROLE` AND they don't share a common owner with the account being operated on
     - If neither credential exists nor the privileged role condition is met, revert with `NotAuthorized`

3. **Account Credential Check**:
   - Only performed if the account being operated on has a different EVC owner than the caller
   - Determine the EVC owner of the account being operated on
   - If no owner is registered, assume the account itself is the owner
   - If the owner lacks valid Keyring credential according to the policy ID:
     - Check if they have the `PRIVILEGED_ACCOUNT_ROLE`
     - If neither credential nor privileged role exists, revert with `NotAuthorized`

4. **Privileged Account Restrictions**:
   - When a user tries to operate on an account that shares the same EVC owner, they cannot use their privileged status to bypass credential checks
   - This means that privileged accounts must have valid credentials to perform operations on their own accounts
   - However, privileged accounts can bypass credential checks when operating on accounts that belong to a different EVC owner

This mechanism ensures that both the entity initiating the operation and the entity being affected by it (if different) have proper authorization, while maintaining strict controls on privileged account usage.

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
- Does not perform Keyring credential checks on any additional accounts

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
- The Swapper and SwapVerifier contracts are granted the PRIVILEGED_ACCOUNT_ROLE to enable asset withdrawals for swaps while preventing self-deposits

To achieve the above, the following operations should be hooked: `OP_DEPOSIT`, `OP_MINT`, `OP_WITHDRAW`, `OP_REDEEM`, `OP_SKIM`, `OP_BORROW`, `OP_REPAY`, `OP_REPAY_WITH_SHARES`, `OP_PULL_DEBT`, `OP_LIQUIDATE` and `OP_FLASHLOAN`.

The liquidators should be granted the `WILD_CARD` role so that they can liquidate and close the position without needing to obtain a Keyring credential.

The Swapper and the SwapVerifier contracts should be granted the `PRIVILEGED_ACCOUNT_ROLE` to enable them to:
- Receive the assets withdrawn from user accounts for swapping
- Deposit/skim swapped assets back into user accounts
- Repay debt on behalf of users

However, the Swapper cannot deposit assets into its own account since the `_authenticateCallerAndAccount` function prevents privileged accounts from performing operations on accounts that share their EVC owner. This means that while the Swapper can operate on user accounts (which have different EVC owners), it must have valid credentials to perform operations on its own account.