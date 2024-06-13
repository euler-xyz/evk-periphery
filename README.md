# Euler Vault Kit Periphery
Periphery contracts for the [Euler Vault Kit](https://github.com/euler-xyz/euler-vault-kit) and [Euler Price Oracle](https://github.com/euler-xyz/euler-price-oracle).

> The Euler Vault Kit is a system for constructing credit vaults. Credit vaults are ERC-4626 vaults with added borrowing functionality. Unlike typical ERC-4626 vaults which earn yield by actively investing deposited funds, credit vaults are passive lending pools. See the [whitepaper](https://docs.euler.finance/euler-vault-kit-white-paper/) for more details.

> Euler Price Oracles is a library of modular oracle adapters and components that implement `IPriceOracle`, an opinionated quote-based interface.

The periphery consists of 4 components that are designed to be used on-chain: IRMFactory, OracleFactory, Perspectives, Swaps. Also included is an off-chain component called Lens, which is purely to assist with off-chain querying of chain-state.

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

Factory for deploying Kink IRMs, used by EVK vaults. This does some basic parameter validation, and tracks the addresses of created IRMs, so that the deployment provenance of IRM instances can be verified by perspectives.

### OracleFactory

Directory: [src/OracleFactory](src/OracleFactory)

Contains a factory for `EulerRouter` and an adapter registry, used by perspectives to verify the deployment provenance of an EVK vault's oracle configuration.

### Swaps

Directory: [src/Swaps](src/Swaps)

[Docs](./docs/swaps.md)

Utilities for performing DEX swaps for EVK vault operations.

`Swapper.sol` and the handlers are considered to live outside the trusted code-base. Swapper invocations should always be followed by a call to one of `SwapVerifier`'s methods. `SwapVerifier.sol` *is* considered part of the trusted code-base.


## Lens

Directory: [src/Lens](src/Lens)

Getter contracts for querying vault and oracle information conveniently. Intended for off-chain usage e.g. in a front-end application.


## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using EVK Periphery to ensure it interacts correctly with your code.

EVK Periphery is currently unaudited and should not be used in production.

## License

(c) 2024 Euler Labs Ltd.

The Euler Vault Kit Periphery code is licensed under the [GPL-2.0-or-later](LICENSE) license.
