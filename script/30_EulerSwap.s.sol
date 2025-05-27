// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {BatchBuilder} from "./utils/ScriptUtils.s.sol";

interface IEulerSwapFactory {
    /// @dev Immutable pool parameters. Passed to the instance via proxy trailing data.
    struct Params {
        // Entities
        address vault0;
        address vault1;
        address eulerAccount;
        // Curve
        uint112 equilibriumReserve0;
        uint112 equilibriumReserve1;
        uint256 priceX;
        uint256 priceY;
        uint256 concentrationX;
        uint256 concentrationY;
        // Fees
        uint256 fee;
        uint256 protocolFee;
        address protocolFeeRecipient;
    }

    /// @dev Starting configuration of pool storage.
    struct InitialState {
        uint112 currReserve0;
        uint112 currReserve1;
    }

    /// @notice Deploy a new EulerSwap pool with the given parameters
    /// @dev The pool address is deterministically generated using CREATE2 with a salt derived from
    ///      the euler account address and provided salt parameter. This allows the pool address to be
    ///      predicted before deployment.
    /// @param params Core pool parameters including vaults, account, fees, and curve shape
    /// @param initialState Initial state of the pool
    /// @param salt Unique value to generate deterministic pool address
    /// @return Address of the newly deployed pool
    function deployPool(Params memory params, InitialState memory initialState, bytes32 salt)
        external
        returns (address);

    /// @notice Uninstalls the pool associated with the Euler account
    /// @dev This function removes the pool from the factory's tracking and emits a PoolUninstalled event
    /// @dev The function can only be called by the Euler account that owns the pool
    /// @dev If no pool is installed for the caller, the function returns without any action
    function uninstallPool() external;

    /// @notice Returns the pool address associated with a specific holder
    /// @dev Returns the pool address from the EulerAccountState mapping for the given holder
    /// @param who The address of the holder to query
    /// @return The address of the pool associated with the holder
    function poolByEulerAccount(address who) external view returns (address);
}

contract EulerSwapOperatorDeployer is BatchBuilder {
    function run() public broadcast {
        string memory inputScriptFileName = "30_EulerSwap_input.json";
        string memory outputScriptFileName = "30_EulerSwap_output.json";
        string memory json = getScriptFile(inputScriptFileName);

        IEulerSwapFactory.Params memory params;
        IEulerSwapFactory.InitialState memory initialState;
        address eulerSwapFactory = vm.parseJsonAddress(json, ".eulerSwapFactory");
        address pool = vm.parseJsonAddress(json, ".pool");
        bytes32 salt = vm.parseJsonBytes32(json, ".salt");
        params.vault0 = vm.parseJsonAddress(json, ".vault0");
        params.vault1 = vm.parseJsonAddress(json, ".vault1");
        params.eulerAccount = vm.parseJsonAddress(json, ".eulerAccount");
        params.equilibriumReserve0 = uint112(vm.parseJsonUint(json, ".equilibriumReserve0"));
        params.equilibriumReserve1 = uint112(vm.parseJsonUint(json, ".equilibriumReserve1"));
        params.priceX = vm.parseJsonUint(json, ".priceX");
        params.priceY = vm.parseJsonUint(json, ".priceY");
        params.concentrationX = vm.parseJsonUint(json, ".concentrationX");
        params.concentrationY = vm.parseJsonUint(json, ".concentrationY");
        params.fee = vm.parseJsonUint(json, ".fee");
        params.protocolFee = vm.parseJsonUint(json, ".protocolFee");
        params.protocolFeeRecipient = vm.parseJsonAddress(json, ".protocolFeeRecipient");
        initialState.currReserve0 = uint112(vm.parseJsonUint(json, ".currReserve0"));
        initialState.currReserve1 = uint112(vm.parseJsonUint(json, ".currReserve1"));

        execute(eulerSwapFactory, pool, params, initialState, salt);

        string memory object;
        object = vm.serializeAddress("pool", "pool", pool);
        vm.writeJson(object, string.concat(vm.projectRoot(), "/script/", outputScriptFileName));
    }

    function deploy(
        address eulerSwapFactory,
        address pool,
        IEulerSwapFactory.Params memory params,
        IEulerSwapFactory.InitialState memory initialState,
        bytes32 salt
    ) public broadcast {
        execute(eulerSwapFactory, pool, params, initialState, salt);
    }

    function execute(
        address eulerSwapFactory,
        address pool,
        IEulerSwapFactory.Params memory params,
        IEulerSwapFactory.InitialState memory initialState,
        bytes32 salt
    ) public {
        address onBehalfOfAccount = getAppropriateOnBehalfOfAccount();
        address currentPool = IEulerSwapFactory(eulerSwapFactory).poolByEulerAccount(onBehalfOfAccount);

        if (currentPool != address(0)) {
            addBatchItem(
                coreAddresses.evc,
                address(0),
                abi.encodeCall(IEVC.setAccountOperator, (onBehalfOfAccount, currentPool, false))
            );
            addBatchItem(eulerSwapFactory, onBehalfOfAccount, abi.encodeCall(IEulerSwapFactory.uninstallPool, ()));
        }

        addBatchItem(
            coreAddresses.evc, address(0), abi.encodeCall(IEVC.setAccountOperator, (onBehalfOfAccount, pool, true))
        );
        addBatchItem(
            eulerSwapFactory,
            onBehalfOfAccount,
            abi.encodeCall(IEulerSwapFactory.deployPool, (params, initialState, salt))
        );
        executeBatch();
    }
}
