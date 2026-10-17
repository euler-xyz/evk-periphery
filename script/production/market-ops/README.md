# Dynamic Market Ops Cluster

`DynamicCluster.s.sol` exposes the existing `ManageClusterBase` behavior through
a request-scoped JSON input. It is intended as the EVK-owned planning and
simulation entrypoint used by a controlled Market Ops provider.

The entrypoint does not accept calldata from Toolbox. It accepts full desired
cluster state, then lets EVK derive deployments, current-state deltas, critical
sections, EVC batches, and direct, Safe, timelock, risk-steward, or emergency
routing.

## Input

Set:

- `MARKET_OPS_CLUSTER_INPUT` to an absolute input JSON path;
- `MARKET_OPS_DEPLOYER` to the approved bootstrap actor;
- `MARKET_OPS_FORK_BLOCK_NUMBER` to the exact block bound by the input;
- `SCRIPT_OUTPUT_DIR` to an existing, request-scoped output directory;
- `DEPLOYMENT_RPC_URL` and `ADDRESSES_DIR_PATH` as for other production scripts.

All integer fields are decimal strings. This avoids JavaScript precision loss
in provider implementations. Address-aligned arrays preserve the EVK asset and
LTV matrix ordering. The input binds the parent Toolbox request hash, EVK source
commit, chain, exact block, intended deployer, and whether EVK may deploy a
temporary stub oracle.

`example-input.json` documents the complete v1 shape. The example is parser
evidence only and is not a deployable market default.

## Output

When `SCRIPT_OUTPUT_DIR` is set, EVK writes request-scoped copies of:

- `Batches.json`;
- `SafeTransaction_*.json` and `SafeBatchBuilder_*.json` when applicable;
- `TimelockCalls.json` when applicable;
- `Cluster.json`; and
- `MarketOpsManifest.json`, which binds the input bytes, Toolbox request, and
  exact `Batches.json` and `Cluster.json` bytes.

`ClusterAddresses.json` is reserved for a separately approved broadcast flow;
the non-broadcast provider runner never writes it.

Existing scripts keep writing to `script/` when `SCRIPT_OUTPUT_DIR` is absent.

This entrypoint is the EVK execution-semantic core, not the HTTP provider. The
provider must still isolate jobs, pin the fork block, validate the canonical
Toolbox request, map it to this complete desired state, and translate EVK output
into the versioned Toolbox plan and simulation response.

## Provider runner

`plan.sh` is the fail-closed, non-broadcast process boundary for a controlled
provider. It verifies the input's EVK commit and exact RPC block hash, rejects
dirty tracked source and reused output directories, strips Foundry signing
keys, and never passes `--broadcast`. Caller input and output paths may live
outside the EVK checkout: the runner stages an exact input copy inside an
ignored, Foundry-readable request workspace and exports artifacts only after
validating the manifest. Foundry's dry-run transaction and runtime cache paths
are isolated in the same workspace. The request workspace is removed on exit.

`MARKET_OPS_DEPLOYER` supplies the simulated sender to the parent cluster and
the existing nested EVK deployer scripts when no private key is present. It
does not grant signing authority. The runner rejects dirty source, removes
`DEPLOYER_KEY`, and invokes Foundry without `--broadcast`.

Safe-backed routes require an explicit nonce, including an explicit zero. This
prevents EVK's interactive nonce-discovery fallback from reaching the Safe API
inside a deterministic provider job.

The runner accepts route configuration separately from the Toolbox request.
That distinction is intentional: Toolbox supplies reviewed desired semantics,
while the controlled provider derives and configures the applicable deployer,
Safe, timelock, risk-steward, or emergency route from authority evidence. The
selected route is validated by `DynamicCluster` and included in
`MarketOpsManifest.json`.
