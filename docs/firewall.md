# Firewall

The `HookTargetFirewall` is a sophisticated security mechanism designed to integrate with Forta's `SecurityValidator` contract and the Euler Vault Kit (EVK) ecosystem. It acts as a hook target for EVK vaults, providing an additional layer of security by implementing firewall-like functionality.

## Purpose

The primary purpose of the `HookTargetFirewall` is to enforce security policies on vault operations, particularly for high-value or sensitive transactions. It works in conjunction with Forta's `SecurityValidator` contract to ensure that certain operations are properly attested before execution, bringing off-chain exploit detection to on-chain DeFi protocol.

## Key Features

1. Each vault can have its own security policy, including:
    - A set of accepted attesters (including trusted origin addresses)
    - Thresholds for incoming and outgoing transfers (both constant and accumulated within a transaction)
    - An operation counter threshold to limit the frequency of operations that do not require attestation
2. The contract intercepts key vault operations like `deposit`, `withdraw`, `mint`, `redeem`, `borrow`, and `repay`, validating them against the stored policy.
3. For transactions exceeding defined thresholds, `HookTargetFirewall` requires an appropriate attestation to be obtained and saved in the `SecurityValidator` contract prior to the operation being executed.
4. The contract implements a sliding window mechanism to track frequency of operations that do not require attestation, using bit manipulation for gas-efficient storage and calculation.
5. The contract implements an operation counter to prevent replay attacks and preserve the integrity of operations even if they do not require attestation. Operation counter is incremented for each intercepted operation.
6. The contract allows to specify trusted origin addresses which are allowed to bypass the attestation checks.
7. The contract ensures that only authorized vaults (proxies deployed by the recognized EVault factory) can use it.

## How It Works

1. When a vault operation is called and the hooked operations are configured appropriately on the vault, the operation is intercepted by the `HookTargetFirewall`.
2. The contract checks if the operation exceeds the defined thresholds.
3. If thresholds are exceeded, a checkpoint is executed through the `SecurityValidator`.
4. The `SecurityValidator` ensures that the operation has been properly attested by checking for a matching attestation. This attestation can be saved before the transaction (using SSTORE) or at the beginning of the transaction (using TSTORE and the EVC's batching mechanism).
5. The attestation includes:
   - A deadline timestamp
   - An ordered list of execution hashes, which are derived from checkpoint hashes and additional inputs to ensure specificity and proper ordering
6. If a valid attestation exists, the operation proceeds; otherwise, it's blocked.

## Caveats

### Checkpoint Hash Computation

The checkpoint hash is a crucial element in the security mechanism of the `HookTargetFirewall`. It is computed using the following components:

1. The vault address (caller of the hook target)
2. The function selector of the operation being executed
3. A quantized reference amount
4. Static parameters of the operation
5. The authenticated account executing the operation
6. An operation counter associated with the authenticated account

This composition ensures that the checkpoint is unique for each operation (also cross-vault), allows for small runtime changes in the reference amount, and prevents replay attacks.

### Reference Amount Quantization

The reference amount is quantized using a logarithmic function (`log1.01`) before being included in the checkpoint hash. This quantization is necessary because the asset amounts that will be processed can fluctuate slightly between the time the attestation is generated off-chain and when the user transaction is executed on-chain. Without quantization, these small fluctuations could cause different hashes to be produced during the real execution, resulting in a mismatch with the values in the attestation. By quantizing the reference value used in checkpoint hash computation, the `HookTargetFirewall` allows for small variations in asset amounts without invalidating the attestation.

### Handling of Maximum Values

When operations involve `type(uint256).max` as an amount (often used to represent "all available" in token operations), special handling is required. The `HookTargetFirewall` resolves these maximum values to concrete asset amounts before applying thresholds and computing checkpoint hashes.

### Operation Counter Mechanism

The `HookTargetFirewall` uses a sliding window approach to track frequency of operations that do not require attestation:

1. It uses a `uint96` to store three 32-bit counters, each representing a 1-minute window.
2. As time passes, the counters are shifted, and new operations increment the current window's counter.
3. The total operation count over the last 3 minutes is used to determine if the operation frequency threshold has been exceeded.

### Vault Authentication

The `HookTargetFirewall` ensures that only authorized vaults can use its services. It uses the `GenericFactory` contract to verify that the calling vault is a proxy deployed by the recognized EVault factory.
