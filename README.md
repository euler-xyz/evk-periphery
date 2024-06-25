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

This is an immutable factory contract for deploying Linear Kink IRM instances, used by EVK vaults. It does some basic parameter validation and tracks the addresses of created IRMs, so that the deployment provenance of IRM instances can be verified by perspectives. Linear Kink IRMs are immutable and stateless.

### OracleFactory

Directory: [src/OracleFactory](src/OracleFactory)

#### EulerRouterFactory

This is an immutable contract that can be used to deploy instances of `EulerRouter`. It allows the deployment provenance of router instances to be verified by perspectives.

* Although the factory (and implementation) is immutable, the routers themselves are created with a user-specifiable address as the governor so that adapters can be installed. If a perspective wishes for the routers to be immutable, it must also confirm this governor has been changed to `address(0)`.
* Routers can have fallbacks specified. If present, these must also be verified to be safe.

#### AdapterRegistry

Although the root of trust of a router can be verified through `OracleFactory`, individual adapters cannot. Because of the large variety of adapters, and also because it is difficult to determine the safety of various adapter parameters on-chain, the root of trust of adapters is difficult to verify. The adapter registry is one possible solution to this. It is a governed whitelist contract, where a governor can add new adapters and revoke existing ones. Perspectives who trust the governor of the registry can verify that each adapter was added there.

* Querying the AdapterRegistry takes a `snapshotTime` parameter. This can be used to query the registry state at a point in the past. This allows a user who doesn't trust the registry to verify each apadter that was installed at a given time, and be confident that the governor can never alter this set. If you do trust the governor, the `snapshotTime` can simply be `block.timestamp`.
* After revoking, an adapter can never be added back again. Instead, simply deploy an identical one at a new address.


### Swaps

Directory: [src/Swaps](src/Swaps)

[Docs](./docs/swaps.md)

Utilities for performing DEX swaps for EVK vault operations.

`Swapper.sol` and the handlers are considered to live outside the trusted code-base. Swapper invocations should always be followed by a call to one of `SwapVerifier`'s methods. `SwapVerifier.sol` *is* considered part of the trusted code-base.

Fork tests require `.env` file with `MAINNET_RPC_URL` variable set to a provider with archive node support, like Alchemy.

## Lens

Directory: [src/Lens](src/Lens)

Getter contracts for querying vault and oracle information conveniently. Intended for off-chain usage e.g. in a front-end application.

### Deploying lenses

Copy [.env.example](.env.example) to `.env` and set `REMOTE_RPC_URL`, `MNEMONIC` and `VERIFIER_API_KEY`
Run:

```bash
forge build
source .env
forge script scripts/DeployLenses.sol:DeployLenses --rpc-url $REMOTE_RPC_URL --broadcast -vvvv --slow --skip-simulation
```


## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using EVK Periphery to ensure it interacts correctly with your code.

EVK Periphery is currently unaudited and should not be used in production.

## License

(c) 2024 Euler Labs Ltd.

The Euler Vault Kit Periphery code is licensed under the [GPL-2.0-or-later](LICENSE) license.
