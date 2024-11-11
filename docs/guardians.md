# Guardians

A guardian is an entity that has the ability to pause one or more vaults. Because the [EVK](https://github.com/euler-xyz/euler-vault-kit) is designed to work for many different use-cases, guardian implementations and policies are external to the contract. Three different Guardian implementations are included in the EVK periphery, each with different properties.


## FactoryGovernor

This is a contract that is intended to be installed as the `upgradeAdmin` of the `GenericFactory` that is used to create EVK vaults. When invoked by a caller of suitable privilege, this contract will invoke methods on the factory.

There are 3 privilege levels: default admin and guardian.

* Default admins can invoke the factory with arbitrary calldata using the `adminCall()` function.
* Pause Guardians can call `pause()` which replaces the factory implementation with a [ReadOnlyProxy](#ReadOnlyProxy) instance. To unpause, a default admins should use `adminCall()` to reinstate a (possibly fixed) implementation.
* Unpause Guardians can call `unpause()` to reinstate a previously paused implementation in case the factory implementation was replaced with a [ReadOnlyProxy](#ReadOnlyProxy) instance due to a false positive.

Note that invoking `pause()` on a `FactoryGovernor` will instantly pause all upgradeable vaults created by this factory, so it should be used with caution. Non-upgradeable vaults will be unaffected.

### ReadOnlyProxy

This is a simple proxy contract that forwards all calls to an wrapped implementation. However, it always invokes the calls with `staticcall`, meaning that read-only operations will succeed, but any operations that perform state modifications will fail.

The intent behind this contract is to minimise the damage to third-party integrations in the event of a pause. State-changing operations will fail until the contract is unpaused, but at least operations like reading balance and debt amounts will succeed.

Note that this contract uses a `staticcall`-to-self trick [similar to the EVK](https://github.com/euler-xyz/euler-vault-kit/blob/master/docs/whitepaper.md#delegatecall-into-view-functions).


## GovernorGuardian

Instances of this contract are intended to be installed as the governor of one or more EVK vaults. Similarly to `FactoryGovernor`, these are proxy-like contracts that allow users with the default admin role to invoke the vault with `adminCall()`, and users with the guardian role to `pause()`.

In addition, there is an `unpause()` function that can be invoked by anybody, once a `PAUSE_DURATION` amount of time has passed. Guardians can unpause immediately.

A `PAUSE_COOLDOWN` parameter prevents a guardian from continually pausing a vault: They must wait until a certain amount of time has elapsed after the previous pause.

In order to allow selective re-enabling of methods, guardians can invoke a `changePauseStatus()` function. This could be used to re-enable a subset of functionality, for example permitting withdrawals and repays but blocking a method that was discovered to contain buggy behaviour.


## HookTargetGuardian

Similar to `GovernorGuardian`, this contract can be associated with one or more vaults. Instead of being installed as a governor however, instances of this contract are installed as hook targets.

The advantage of using a hook target guardian is that multiple vaults can be instantly paused by one invocation of the hook guardian, as opposed to individually pausing multiple vaults. The guardian may not even know about all the different vaults it is pausing. However, the hook target guardian adds an extra gas overhead for normal operations on the vault.

Similarly to `GovernorGuardian`, there is an `unpause()` function. Although it can only be called by the guardian, the operations get unpaused automatically after a `PAUSE_DURATION` amount of time.

Same as for `GovernorGuardian`, a `PAUSE_COOLDOWN` parameter prevents a guardian from continually pausing a vault: They must wait until a certain amount of time has elapsed after the previous pause.