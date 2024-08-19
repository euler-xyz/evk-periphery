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

- `implementation` - Supporting contracts that may be used by multiple perspectives.
- `deployed` - Concrete instances of perspectives to be deployed.

### IRMFactory

Directory: [src/IRMFactory](src/IRMFactory)

Immutable factory contracts for deploying IRM instances. They do some parameter validation and track the addresses of created IRMs, so that the deployment provenance of IRM instances can be verified by perspectives. All deployed IRMs are immutable and stateless.

### IRM

Directory: [src/IRM](src/IRM)

Alternative interest rate models for use by EVK vaults.

- IRMAdaptiveLinearKink is a Linear Kink model with an adaptive mechanism based on exponential growth/decay. As utilization persists above/below the kink the Linear Kink IRM is translated up/down. This model is based on Morpho's [AdaptiveCurveIrm](https://github.com/morpho-org/morpho-blue-irm/blob/8242d5d0414b75368f150d251b518a6c9cf797af/src/adaptive-curve-irm/AdaptiveCurveIrm.sol). More information: [Morpho docs](https://docs.morpho.org/morpho/contracts/irm/adaptive-curve-irm/), [LlamaRisk explainer](https://www.llamarisk.com/research/morph-crvusd-vault-irm).

- IRMAdaptiveRange is a Linear Kink model with an adaptive mechanism based on exponential growth/decay. As utilization persists above/below a range around the kink the Linear Kink IRM is adapted to increase/decrease rates. This model is based on Frax's [VariableInterestRate](https://github.com/FraxFinance/fraxlend/blob/f474378c87910f23e3bb135c0e42057afee573b7/src/contracts/VariableInterestRate.sol). More information: [Fraxlend docs](https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#variable-rate-v2-interest-rate), [LlamaRisk explainer](https://www.llamarisk.com/research/sturdy-crvusd-aggregator-interest-rate-model-upgrade).

### EulerRouterFactory

Directory: [src/EulerRouterFactory](src/EulerRouterFactory)

This is an immutable contract that can be used to deploy instances of `EulerRouter`. It allows the deployment provenance of router instances to be verified by perspectives.

- Although the factory (and implementation) is immutable, the routers themselves are created with a user-specifiable address as the governor so that adapters can be installed. If a perspective wishes for the routers to be immutable, it must also confirm this governor has been changed to `address(0)`.
- Routers can have fallbacks specified. If present, these must also be verified to be safe.

### SnapshotRegistry

Directory: [src/SnapshotRegistry](src/SnapshotRegistry)

Although the root of trust of a router can be verified through `OracleFactory`, individual adapters cannot. Because of the large variety of adapters, and also because it is difficult to determine the safety of various adapter parameters on-chain, the root of trust of adapters is difficult to verify. The adapter registry is one possible solution to this. It is a governed whitelist contract, where a governor can add new adapters and revoke existing ones. Perspectives who trust the governor of the registry can verify that each adapter was added there.

- Querying the SnapshotRegistry takes a `snapshotTime` parameter. This can be used to query the registry state at a point in the past. This allows a user who doesn't trust the registry to verify each apadter that was installed at a given time, and be confident that the governor can never alter this set. If you do trust the governor, the `snapshotTime` can simply be `block.timestamp`.
- After revoking, an adapter can never be added back again. Instead, simply deploy an identical one at a new address.

SnapshotRegistry can also be used as a whitelist for external ERC4626 vaults that can be configured as internally resolved vaults in `EulerRouter`. Practically speaking this allows a perspective to recognize ERC4626 yield-bearing tokens as collateral or liability.

SnapshotRegistry can also be used as a whitelist for other smart contracts (i.e. IRMs).

### Swaps

Directory: [src/Swaps](src/Swaps)

[Docs](./docs/swaps.md)

Utilities for performing DEX swaps for EVK vault operations.

`Swapper.sol` and the handlers are considered to live outside the trusted code-base. Swapper invocations should always be followed by a call to one of `SwapVerifier`'s methods. `SwapVerifier.sol` _is_ considered part of the trusted code-base.

Fork tests require `.env` file with `FORK_RPC_URL` variable set to a provider with archive node support, like Alchemy.

## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using EVK Periphery to ensure it interacts correctly with your code.

EVK Periphery is currently unaudited and should not be used in production.

## License

(c) 2024 Euler Labs Ltd.

The Euler Vault Kit Periphery code is licensed under the [GPL-2.0-or-later](LICENSE) license.
