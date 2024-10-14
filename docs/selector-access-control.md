# Selector Access Control

The EVK periphery includes two access control implementations that leverage the `SelectorAccessControl` contract to provide fine-grained control over function calls: `GovernorAccessControl` and `HookTargetAccessControl`. These contracts allow for selective permissioning of specific functions to authorized callers depending on the use case.

## `SelectorAccessControl`

This is the base contract that provides the core functionality for selector-based access control. It extends OpenZeppelin's `AccessControlEnumerableUpgradeable` and integrates with the Ethereum Vault Connector (EVC).

This contract allows granting and revoking roles for specific function selectors, but also supports a `WILD_CARD` role that grants access to all function selectors. Combined with `_authenticateCaller` function, which checks if the caller has either the wildcard role or the specific role for the current function selector, this provides a flexible access control mechanism.

`SelectorAccessControl` integrates with the EVC to allow custom EVC-based authentication flows. Utilization of the unstructured storage allows this contract to be safely delegatecall'ed.

## `GovernorAccessControl`

This contract is designed to be used as a governor for EVK vaults. It extends `SelectorAccessControl` and adds functionality to forward calls to target contracts.

This contract can be installed as the governor of one or more EVK vaults and allows whitelisted callers to invoke specific functions on target contracts. It uses a fallback function to authenticate the caller and forward the call to the target contract. The address of the target contract is expected to be appended by the caller as trailing calldata and is extracted from it accordingly.

The `GovernorAccessControl` contract also includes emergency functionality for certain critical operations. This allows authorized users to perform emergency actions without needing the full selector role:
1. Emergency LTV Adjustment: Users with the `LTV_EMERGENCY_ROLE` can lower the borrow LTV without changing the liquidation LTV. This uses the current ramp duration if active, or applies changes immediately if no ramp is ongoing.
2. Emergency Vault Pausing: Users with the `HOOK_EMERGENCY_ROLE` can disable all operations on the vault.
3. Emergency Caps Lowering: Users with the `CAPS_EMERGENCY_ROLE` can lower supply and/or borrow caps.

These emergency roles provide a way to quickly respond to critical situations without compromising the overall access control structure of the governor.

Usage:
1. Deploy an instance of `GovernorAccessControl`, specifying the EVC address and the default admin
2. Grant roles to addresses for specific function selectors or the `WILD_CARD`
3. Install the `GovernorAccessControl` instance as the governor of the desired vault(s)
4. Authorized callers can now invoke permitted functions on the vault through the governor contract

## `HookTargetAccessControl`

This contract is designed to be used as a hook target for EVK vaults. It combines the functionality of `SelectorAccessControl` and `BaseHookTarget` to provide access control at the hook level.

This contract can be associated with one or more vaults deployed by the specified EVault factory as a hook target and allows specific operations on the vault to be executed only by whitelisted callers.

Usage:
1. Deploy an instance of `HookTargetAccessControl`, specifying the EVC address, default admin, and associated EVault factory address
2. Grant roles to addresses for specific function selectors or the `WILD_CARD`
3. Install the `HookTargetAccessControl` instance as a hook target for the desired vault(s) and configure hooked operations
4. The vault will now enforce access control checks for hooked operations