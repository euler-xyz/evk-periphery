# Selector Access Control

The EVK periphery includes two access control implementations that leverage the `SelectorAccessControl` contract to provide fine-grained control over function calls in the following contracts: `GovernorAccessControl` and `HookTargetAccessControl`. These contracts allow for selective permissioning of specific functions to authorized callers depending on the use case.

## Access Control Framework Overview

The system implements a security model where:

1. Access to functions is controlled by function selectors
2. Roles can be granted for specific function selectors
3. Special roles (like `WILD_CARD`) can be granted for broader access
4. If used as a governor, further integration with timelocks provides time-delayed security for critical operations

## `SelectorAccessControl`

This is the base contract that provides the core functionality for selector-based access control. It extends OpenZeppelin's `AccessControlEnumerableUpgradeable` and integrates with the Ethereum Vault Connector (EVC).

This contract allows granting and revoking roles for specific function selectors, but also supports a `WILD_CARD` role that grants access to all function selectors. Combined with `_authenticateCaller` function, which checks if the caller has either the wildcard role or the specific role for the current function selector, this provides a flexible access control mechanism.

`SelectorAccessControl` integrates with the EVC to allow custom EVC-based authentication flows. Utilization of the unstructured storage allows this contract to be safely delegatecall'ed.

### Role Structure

The key roles in the system include:

- `DEFAULT_ADMIN_ROLE`: Can grant and revoke other roles
- `WILD_CARD`: Has access to call any function selector
- Function-specific roles: Named by the function selector hash, grants access to specific functions only

## Governance Flow

When used as a vault governor:

1. A caller makes a request to the governor contract with the target function selector
2. The governor authenticates the caller's permission for that function
3. If authenticated, the governor forwards the call to the target vault
4. The vault executes the requested function

This indirection allows function-level access control to be managed separately from the vault implementation.

### `GovernorAccessControl`

This contract is designed to be used as a governor for EVK vaults. It extends `SelectorAccessControl` and adds functionality to forward calls to target contracts.

This contract can be installed as the governor of one or more EVK vaults and allows whitelisted callers to invoke specific functions on target contracts. It uses a fallback function to authenticate the caller and forward the call to the target contract. The address of the target contract is expected to be appended by the caller as trailing calldata and is extracted from it accordingly.

### `GovernorAccessControlEmergency`

The `GovernorAccessControlEmergency` inherits from `GovernorAccessControl` and includes emergency functionality for certain critical operations. This allows authorized users to perform emergency actions without needing the full selector role:

1. Emergency LTV Adjustment: Users with the `LTV_EMERGENCY_ROLE` can lower the borrow LTV without changing the liquidation LTV. As with all changes to borrow LTV, this takes effect immediately. The current ramp state for liquidation LTV (if any) is preserved.
2. Emergency Vault Pausing: Users with the `HOOK_EMERGENCY_ROLE` can disable all operations on the vault.
3. Emergency Caps Lowering: Users with the `CAPS_EMERGENCY_ROLE` can lower supply and/or borrow caps.

These emergency roles provide a way to quickly respond to critical situations without compromising the overall access control structure of the governor.

### Integration with Timelocks

In the complete governance framework (as deployed by the `GovernorAccessControlEmergencyFactory`), the governor contract integrates with two timelocks:

1. An admin timelock that holds the `DEFAULT_ADMIN_ROLE` and controls the governance of the governor itself
2. A wildcard timelock that holds the `WILD_CARD` role and controls day-to-day governance operations

This separation creates a security model where routine governance actions are time-delayed through the wildcard timelock, while still allowing rapid emergency responses through dedicated guardian roles.

### Usage with Factory Deployment

The recommended way to deploy the governance-based access control system is through the `GovernorAccessControlEmergencyFactory`, which sets up the complete governance framework:

1. Deploy the governance suite using the factory
2. Install the governor as the governor of your vault(s)
3. Use timelocks for standard governance operations
4. Use emergency roles for rapid risk responses

For detailed instructions on factory deployment, see the [Governor Access Control Emergency Factory documentation](./governor-access-control-emergency-factory.md).

### Stand-alone Usage

If you prefer to deploy the components individually:

1. Deploy an instance of `GovernorAccessControl` or `GovernorAccessControlEmergency`, specifying the EVC address and the default admin
2. Grant roles to addresses for specific function selectors or the `WILD_CARD`
3. Install the deployed governor access control instance as the governor of the desired vault(s)
4. Authorized callers can now invoke permitted functions on the vault through the governor contract

## `CapRiskSteward`

This contract is a specialized risk management contract that combines `SelectorAccessControl` with controlled parameter adjustment capabilities for EVK vaults. It is compatible with the `GovernorAccessControl` and `GovernorAccessControlEmergency` contracts and enables authorized users to modify vault parameters (caps and interest rate models) while enforcing safety limits.

`CapRiskSteward` allows authorized users to increase/decrease supply and borrow caps by up to 50% over 3 days. The maximum readjustment factor recharges over time. 

`CapRiskSteward` allows authorized users to substitute the interest rate model for an interest model deployed by the recognized factory.

### Usage

1. Deploy the `CapRiskSteward` contract, specifying the address of the `GovernorAccessControl` or `GovernorAccessControlEmergency` contract installed on the vault and and the default admin
2. Grant appropriate roles to addresses that should be able to adjust parameters
3. Grant `setCaps.selector` and `setInterestRateModel.selector` roles to the `CapRiskSteward` contract

## `HookTargetAccessControl`

This contract is designed to be used as a hook target for EVK vaults. It combines the functionality of `SelectorAccessControl` and `BaseHookTarget` to provide access control at the hook level.

This contract can be associated with one or more vaults deployed by the specified EVault factory as a hook target and allows specific operations on the vault to be executed only by whitelisted callers.

### Usage

1. Deploy an instance of `HookTargetAccessControl`, specifying the EVC address, default admin, and associated EVault factory address
2. Grant roles to addresses for specific function selectors or the `WILD_CARD`
3. Install the `HookTargetAccessControl` instance as a hook target for the desired vault(s) and configure hooked operations
4. The vault will now enforce access control checks for hooked operations
