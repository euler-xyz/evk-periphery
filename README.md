# Euler Vault Kit Periphery
Periphery contracts for the [Euler Vault Kit](https://github.com/euler-xyz/euler-vault-kit) and [Euler Price Oracle](https://github.com/euler-xyz/euler-price-oracle).

> The Euler Vault Kit is a system for constructing credit vaults. Credit vaults are ERC-4626 vaults with added borrowing functionality. Unlike typical ERC-4626 vaults which earn yield by actively investing deposited funds, credit vaults are passive lending pools. See the [whitepaper](https://docs.euler.finance/euler-vault-kit-white-paper/) for more details.

> Euler Price Oracles is a library of modular oracle adapters and components that implement `IPriceOracle`, an opinionated quote-based interface.

The periphery consists of several components designed to be used both on-chain and off-chain to support the Euler Vault Kit ecosystem.

## On-Chain Components

### Perspectives

Directory: [src/Perspectives](src/Perspectives)

[Docs](https://docs.euler.finance/euler-vault-kit-white-paper/#perspectives)

Contracts that encode validity criteria for EVK vaults.

There are two sub-directories:

* `implementation` - Supporting contracts that may be used by multiple perspectives.
* `deployed` - Concrete instances of perspectives to be deployed.

### IRMFactory

Directory: [src/IRMFactory](src/IRMFactory)

This is an immutable factory contract for deploying Linear Kink IRM instances, used by EVK vaults. It does some basic parameter validation and tracks the addresses of created IRMs, so that the deployment provenance of IRM instances can be verified by perspectives. Linear Kink IRMs are immutable and stateless.

### EulerRouterFactory

Directory: [src/EulerRouterFactory](src/EulerRouterFactory)

This is an immutable contract that can be used to deploy instances of `EulerRouter`. It allows the deployment provenance of router instances to be verified by perspectives.

* Although the factory (and implementation) is immutable, the routers themselves are created with a user-specifiable address as the governor so that adapters can be installed. If a perspective wishes for the routers to be immutable, it must also confirm this governor has been changed to `address(0)`.
* Routers can have fallbacks specified. If present, these must also be verified to be safe.

### SnapshotRegistry

Directory: [src/SnapshotRegistry](src/SnapshotRegistry)

A governed whitelist contract for tracking trusted adapters and other components. It provides historical querying capabilities and permanent revocation of entries.

* Querying uses a `snapshotTime` parameter to view historical state
* Revoked entries cannot be re-added
* Can whitelist oracle adapters, ERC4626 vaults, and other contracts like IRMs

### Swaps

Directory: [src/Swaps](src/Swaps)

[Docs](./docs/swaps.md)

Utilities for performing DEX swaps for EVK vault operations. Includes a main Swapper contract and various DEX-specific handlers.

* `Swapper.sol` and handlers are considered untrusted code
* `SwapVerifier.sol` provides trusted verification of swap outcomes
* Includes handlers for different DEX protocols

### Lens

Directory: [src/Lens](src/Lens)

Off-chain utilities for querying on-chain state. Includes multiple specialized lens contracts:

* `AccountLens` - For querying account-level information
* `VaultLens` - For querying vault-specific data
* `OracleLens` - For querying oracle prices and configurations
* `EulerEarnVaultLens` - For querying Euler Earn vault specifics
* `IRMLens` - For querying Interest Rate Model data
* `UtilsLens` - For general utility queries

### AccessControl

Directory: [src/AccessControl](src/AccessControl)

Function-level access control system using selector-based permissions, allowing granular control over who can call specific contract functions.

### Governor

Directory: [src/Governor](src/Governor)

A comprehensive governance contracts system including:
* Factory-based governor deployment
* Tiered access control system
* Emergency access control mechanisms
* Guardian functionality

### ERC20

Directory: [src/ERC20](src/ERC20)

Custom ERC20 token implementations and extensions.

### HookTarget

Directory: [src/HookTarget](src/HookTarget)

Extensible hook system for vault operations:
* Access control integration
* Guardian-specific hooks

### Liquidator

Directory: [src/Liquidator](src/Liquidator)

Custom liquidator contracts.

### TermsOfUseSigner

Directory: [src/TermsOfUseSigner](src/TermsOfUseSigner)

Contracts managing the signing and verification of terms of use.

## Development

Fork tests require `.env` file with `FORK_RPC_URL` variable set to a provider with archive node support, like Alchemy.

## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using EVK Periphery to ensure it interacts correctly with your code.

## License

(c) 2024 Euler Labs Ltd.

The Euler Vault Kit Periphery code is licensed under the [GPL-2.0-or-later](LICENSE) license.
