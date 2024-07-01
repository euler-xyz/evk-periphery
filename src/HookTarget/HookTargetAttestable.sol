// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {AmountCap} from "evk/EVault/shared/types/AmountCap.sol";
import {Errors} from "evk/EVault/shared/Errors.sol";
import {ISecurityPolicy} from "./interfaces/ISecurityPolicy.sol";
import {ISecurityValidator} from "./interfaces/ISecurityValidator.sol";

contract HookTargetAttestable is IHookTarget, ISecurityPolicy, Errors {
    enum TransferType {
        In,
        Out
    }

    struct Policy {
        address attester;
        AmountCap inConstantThreshold;
        AmountCap inAccumulatedThreshold;
        AmountCap outConstantThreshold;
        AmountCap outAccumulatedThreshold;
    }

    IEVC public evc;
    ISecurityValidator public validator;
    mapping(address => Policy) public policies;

    constructor(address _evc, address _validator) {
        evc = IEVC(_evc);
        validator = ISecurityValidator(_validator);
    }

    modifier governorOnly(address vault) {
        if (msg.sender != IEVault(vault).governorAdmin()) revert E_Unauthorized();
        _;
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @inheritdoc ISecurityPolicy
    function saveAttestation(ISecurityValidator.Attestation calldata attestation, bytes calldata attestationSignature)
        external
    {
        validator.saveAttestation(attestation, attestationSignature);
    }

    function setPolicy(
        address vault,
        address attester,
        uint16 inConstantThreshold,
        uint16 inAccumulatedThreshold,
        uint16 outConstantThreshold,
        uint16 outAccumulatedThreshold
    ) external governorOnly(vault) {
        policies[vault] = Policy({
            attester: attester,
            inConstantThreshold: AmountCap.wrap(inConstantThreshold),
            inAccumulatedThreshold: AmountCap.wrap(inAccumulatedThreshold),
            outConstantThreshold: AmountCap.wrap(outConstantThreshold),
            outAccumulatedThreshold: AmountCap.wrap(outAccumulatedThreshold)
        });
    }

    function deposit(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(msg.sender).convertToAssets(IEVault(msg.sender).balanceOf(caller()));
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    function mint(uint256 amount, address receiver) external returns (uint256) {
        IEVault(msg.sender).convertToAssets(amount);
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    function skim(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            uint256 balance = IEVault(IEVault(msg.sender).asset()).balanceOf(msg.sender);
            uint256 cash = IEVault(msg.sender).cash();
            amount = balance > cash ? balance - cash : 0;
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256) {
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    function redeem(uint256 amount, address receiver, address owner) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(msg.sender).convertToAssets(IEVault(msg.sender).balanceOf(owner));
        }
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    function borrow(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).cash();
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver));
        return 0;
    }

    function repay(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).debtOf(caller());
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    function checkVaultStatus() external view returns (bytes4) {
        bool attestationInProgress = validator.getCurrentAttester() == policies[msg.sender].attester;

        if (attestationInProgress && !validator.allCheckpointsExecuted()) {
            revert E_Unauthorized();
        }

        return 0;
    }

    function executeCheckpoint(TransferType transferType, uint256 referenceAmount, bytes memory data) internal {
        Policy memory policy = policies[msg.sender];
        bool attestationInProgress = validator.getCurrentAttester() == policy.attester;

        if (!evc.isSimulationInProgress() && !attestationInProgress) {
            revert E_Unauthorized();
        }

        StorageSlot.Uint256SlotType slot = StorageSlot.asUint256(keccak256(abi.encode(transferType, msg.sender)));
        uint256 accumulator = StorageSlot.tload(slot) + referenceAmount;
        StorageSlot.tstore(slot, accumulator);

        (uint256 constantThreshold, uint256 accumulatedThreshold) = resolveThresholds(transferType, policy);

        if (attestationInProgress && (referenceAmount >= constantThreshold || accumulator >= accumulatedThreshold)) {
            bytes32 checkpointHash = keccak256(abi.encode(msg.sender, bytes4(msg.data), data, caller()));
            validator.executeCheckpoint(checkpointHash);
        }
    }

    function resolveThresholds(TransferType transferType, Policy memory policy)
        internal
        pure
        returns (uint256 constantThreshold, uint256 accumulatedThreshold)
    {
        if (transferType == TransferType.In) {
            constantThreshold = policy.inConstantThreshold.resolve();
            accumulatedThreshold = policy.inAccumulatedThreshold.resolve();
        } else {
            constantThreshold = policy.outConstantThreshold.resolve();
            accumulatedThreshold = policy.outAccumulatedThreshold.resolve();
        }
    }

    function caller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    fallback() external {}
}
