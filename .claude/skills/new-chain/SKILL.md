---
name: new-chain
description: Prepare evk-periphery for deploying Euler on a new EVM chain. Checks the chain's prerequisites, makes the chain-support code changes and opens the PR. Use when asked to add, support or deploy Euler on a new chain.
---

# New chain

`script/NEW_CHAIN.md` is the runbook. This skill covers its steps 1 and 2: checking the chain and changing the code. Deploying, signing and anything else that needs a key stays with a person.

## Never

- Handle private keys, seed phrases or keystore passwords.
- Broadcast a transaction.
- Read `.env` or other secrets without the user's go. Use a public RPC or the one the user gives you.

## Inputs

Ask for any that are missing:
- the chain id and an RPC URL
- the chain's WETH address, or "none"
- the explorer's verification API: Etherscan V2, Blockscout or Sourcify, and its URL

## 1. Check the prerequisites

Run every check and report a pass/fail table. For each failure, say what is missing and who provides it.

| Check | Command | Pass |
|---|---|---|
| Chain id | `cast chain-id --rpc-url $RPC` | equals the chain id |
| Cancun | `cast rpc eth_call '{"data":"0x60015f5d5f5c5f5260205ff3"}' latest --rpc-url $RPC` | returns `0x…01`. An error means no Cancun |
| Permit2 | `cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url $RPC` | has code. If not, the CREATE2 deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C` must have code; a person then deploys Permit2 (runbook step 3) |
| MultiSendCallOnly | `cast code` on `0x40A2aCCbd92BCA938b02010E17A5b8929b49130D` (Safe 1.3.0) and `0x9641d764fc13c8B624c04430C7356C1C7C8102e2` (Safe 1.4.1) | at least one has code |
| Safe hosting | `curl -s -o /dev/null -w '%{http_code}' https://safe-config.safe.global/api/v1/chains/$ID/` | `200`: Safe hosts the chain. `404`: ask the user for the chain's own Safe gateway URL |
| LayerZero | the query below | one entry with at least one eid |
| Merkl Distributor | `cast code 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae --rpc-url $RPC` | has code. If not, ask the user for Merkl's address on the chain |
| WETH | `cast call $WETH "symbol()(string)"` and `"decimals()(uint8)"` | an ETH token with 18 decimals |

```sh
curl -fsSL https://metadata.layerzero-api.com/v1/metadata | jq --argjson id $ID '[to_entries[]
  | select(.value.chainDetails.nativeChainId == $id and .value.chainDetails.chainType == "evm")
  | {chainKey: .key, eids: [.value.deployments[]? | select(.endpointV2 and (.eid|tonumber) >= 30000 and (.eid|tonumber) < 40000) | .eid]}
  | select(.eids | length > 0)]'
```

## 2. Change the code

Open one PR against `development`, titled `feat: <chain name> support` and ready for review. Edit only the files in the runbook's step 2 table, and copy the style of the neighbouring entries. `git show e59e1ef` (Katana) is a worked example.

- **Both `getWETHAddress()` copies** (`script/utils/ScriptUtils.s.sol`, `src/Lens/Utils.sol`): identical entries, either the WETH address or an explicit `address(0)`.
- **`getSafeBaseURL()`:** add the chain to the `safe-client.safe.global` list if Safe hosts it; otherwise add a branch returning the gateway URL.
- **`OFT_CONFIG["EUL"].configOneDirectionChainIds`:** append the chain id.
- **`script/utils/verifyContracts.sh`:** leave it unless a verification later fails with "Chain … not supported".

Then run `forge build`. Don't run `forge fmt` on these files: `50_CoreAndPeriphery.s.sol` is not fmt-clean, and reformatting it buries the change.

## 3. Hand over to a person

List the remaining runbook steps with the values found above:
- Permit2, if it was missing
- the Safes, owned by the deployer
- option 50: dry run first, then for real
- the rEUL whitelist
- option 51
- the Ethereum DAO batch
- verification
- the euler-interfaces PR
- the Safe owners

After the deployment, an agent can check the result without keys:
- Every address in `../euler-interfaces/addresses/<chainId>/` has code.
- Each Safe's `getOwners()` and `getThreshold()` match `euler-interfaces/config/multisig/<key>.json`, and the deployer is no longer an owner.
