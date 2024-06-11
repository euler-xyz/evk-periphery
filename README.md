# Euler Vault Kit Periphery
Periphery contracts for the [Euler Vault Kit](https://github.com/euler-xyz/euler-vault-kit) and [Euler Price Oracle](https://github.com/euler-xyz/euler-price-oracle).

> The Euler Vault Kit is a system for constructing credit vaults. Credit vaults are ERC-4626 vaults with added borrowing functionality. Unlike typical ERC-4626 vaults which earn yield by actively investing deposited funds, credit vaults are passive lending pools. See the [whitepaper](https://docs.euler.finance/euler-vault-kit-white-paper/) for more details.

> Euler Price Oracles is a library of modular oracle adapters and components that implement `IPriceOracle`, an opinionated quote-based interface.

The periphery consists of 5 components: IRMFactory, Lens, OracleFactory, Perspectives, Swaps.

## IRMFactory
Directory: [src/IRMFactory](src/IRMFactory)

Factory for deploying Kink IRMs, used by EVK vaults.

## Lens
Directory: [src/Lens](src/Lens)

Getter contracts for querying vault and oracle information conveniently. Intended for off-chain usage e.g. in a front-end application.

## OracleFactory
Directory: [src/OracleFactory](src/OracleFactory)

Contains a factory for `EulerRouter` and an adapter registry, used by perspectives to verify the root of trust for an EVK vault's oracle configuration.

## Perspectives
Directory: [src/Perspectives](src/Perspectives)

Contracts that encode validity criteria for EVK vaults.

## Swaps
Directory: [src/Swaps](src/Swaps)

Utilities for performing DEX swaps for EVK vault operations.

[Docs](./docs/swaps.md)

## Safety
This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using EVK Periphery to ensure it interacts correctly with your code.

EVK Periphery is currently unaudited and should not be used in production.