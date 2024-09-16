// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {Set, SetStorage} from "ethereum-vault-connector/Set.sol";
import {AmountCap} from "evk/EVault/shared/types/AmountCap.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @notice An interface for the SecurityValidator singleton contract.
interface ISecurityValidator {
    struct Attestation {
        uint256 deadline;
        bytes32[] executionHashes;
    }

    function getCurrentAttester() external view returns (address);
    function executeCheckpoint(bytes32 checkpointHash) external returns (bytes32);
    function hashAttestation(Attestation calldata attestation) external view returns (bytes32);
    function executionHashFrom(bytes32 checkpointHash, address caller, bytes32 executionHash)
        external
        view
        returns (bytes32);
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function storeAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function validateFinalState() external view;
}

/// @title HookTargetFirewall
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A hook target that integrates with the SecurityValidator contract.
contract HookTargetFirewall is IHookTarget, EVCUtil {
    using Set for SetStorage;

    /// @notice Struct to store policy information for a vault.
    struct PolicyStorage {
        /// @notice The set of accepted attesters.
        SetStorage attesters;
        /// @notice The constant threshold for incoming transfers.
        AmountCap inConstantThreshold;
        /// @notice The accumulated threshold for incoming transfers.
        AmountCap inAccumulatedThreshold;
        /// @notice The constant threshold for outgoing transfers.
        AmountCap outConstantThreshold;
        /// @notice The accumulated threshold for outgoing transfers.
        AmountCap outAccumulatedThreshold;
    }

    /// @notice Enum representing the type of transfer.
    enum TransferType {
        /// @notice Represents an incoming transfer.
        In,
        /// @notice Represents an outgoing transfer.
        Out
    }

    /// @notice The security validator contract.
    ISecurityValidator internal immutable validator;

    /// @notice The immutable ID of the attester controller
    bytes32 internal immutable controllerId;

    /// @notice Mapping of vault addresses to their policy storage.
    mapping(address => PolicyStorage) internal policies;

    /// @notice Mapping of address prefixes to their operation counter.
    mapping(bytes19 => uint256) internal operationCounters;

    /// @notice Emitted when the attester controller ID is updated
    /// @param attesterControllerId The new attester controller ID
    event AttesterControllerUpdated(bytes32 attesterControllerId);

    /// @notice Emitted when accepted attesters are inserted for a vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester.
    event AddPolicyAttester(address indexed vault, address attester);

    /// @notice Emitted when an accepted attester is removed for a vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester.
    event RemovePolicyAttester(address indexed vault, address attester);

    /// @notice Emitted when a policy thresholds are set for a vault.
    /// @param vault The address of the vault.
    /// @param inConstantThreshold The constant threshold for incoming transfers.
    /// @param inAccumulatedThreshold The accumulated threshold for incoming transfers.
    /// @param outConstantThreshold The constant threshold for outgoing transfers.
    /// @param outAccumulatedThreshold The accumulated threshold for outgoing transfers.
    event SetPolicyThresholds(
        address indexed vault,
        uint16 inConstantThreshold,
        uint16 inAccumulatedThreshold,
        uint16 outConstantThreshold,
        uint16 outAccumulatedThreshold
    );

    /// @notice Error thrown when the caller is not authorized to perform an operation.
    error HTA_Unauthorized();

    /// @notice Constructor to initialize the contract with the EVC and validator addresses.
    /// @param _evc The address of the EVC contract.
    /// @param _securityValidator The address of the security validator contract.
    constructor(address _evc, address _securityValidator, bytes32 _controllerId) EVCUtil(_evc) {
        validator = ISecurityValidator(_securityValidator);
        controllerId = _controllerId;
        emit AttesterControllerUpdated(_controllerId);
    }

    /// @notice Fallback function to handle unexpected calls.
    fallback() external {}

    /// @notice Modifier to restrict access to only the governor of the specified vault.
    /// @param vault The address of the vault.
    modifier onlyGovernor(address vault) {
        if (_msgSender() != IEVault(vault).governorAdmin()) revert HTA_Unauthorized();
        _;
    }

    /// @inheritdoc IHookTarget
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Retrieves the address of the security validator contract
    /// @return The address of the security validator contract
    function getSecurityValidator() external view returns (address) {
        return address(validator);
    }

    /// @notice Retrieves the attester controller ID
    /// @return The bytes32 representation of the attester controller ID
    function getAttesterControllerId() external view returns (bytes32) {
        return controllerId;
    }

    /// @notice Adds an accepted attester to the policy for a given vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester to be added.
    function addPolicyAttester(address vault, address attester) external onlyEVCAccountOwner onlyGovernor(vault) {
        if (policies[vault].attesters.insert(attester)) {
            emit AddPolicyAttester(vault, attester);
        }
    }

    /// @notice Removes an accepted attester from the policy for a given vault.
    /// @param vault The address of the vault.
    /// @param attester The address of the attester to be removed.
    function removePolicyAttester(address vault, address attester) external onlyEVCAccountOwner onlyGovernor(vault) {
        if (policies[vault].attesters.remove(attester)) {
            emit RemovePolicyAttester(vault, attester);
        }
    }

    /// @notice Retrieves the list of accepted attesters for a given vault.
    /// @param vault The address of the vault.
    /// @return An array of addresses representing the accepted attesters for the specified vault.
    function getPolicyAttesters(address vault) external view returns (address[] memory) {
        return policies[vault].attesters.get();
    }

    /// @notice Sets the policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @param inConstantThreshold The constant threshold for incoming transfers.
    /// @param inAccumulatedThreshold The accumulated threshold for incoming transfers.
    /// @param outConstantThreshold The constant threshold for outgoing transfers.
    /// @param outAccumulatedThreshold The accumulated threshold for outgoing transfers.
    function setPolicyThresholds(
        address vault,
        uint16 inConstantThreshold,
        uint16 inAccumulatedThreshold,
        uint16 outConstantThreshold,
        uint16 outAccumulatedThreshold
    ) external onlyEVCAccountOwner onlyGovernor(vault) {
        PolicyStorage storage policyStorage = policies[vault];
        policyStorage.inConstantThreshold = AmountCap.wrap(inConstantThreshold);
        policyStorage.inAccumulatedThreshold = AmountCap.wrap(inAccumulatedThreshold);
        policyStorage.outConstantThreshold = AmountCap.wrap(outConstantThreshold);
        policyStorage.outAccumulatedThreshold = AmountCap.wrap(outAccumulatedThreshold);

        emit SetPolicyThresholds(
            vault, inConstantThreshold, inAccumulatedThreshold, outConstantThreshold, outAccumulatedThreshold
        );
    }

    /// @notice Retrieves the policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @return inConstantThreshold The constant threshold for incoming transfers.
    /// @return inAccumulatedThreshold The accumulated threshold for incoming transfers.
    /// @return outConstantThreshold The constant threshold for outgoing transfers.
    /// @return outAccumulatedThreshold The accumulated threshold for outgoing transfers.
    function getPolicyThresholds(address vault) external view returns (uint16, uint16, uint16, uint16) {
        PolicyStorage storage policyStorage = policies[vault];
        return (
            AmountCap.unwrap(policyStorage.inConstantThreshold),
            AmountCap.unwrap(policyStorage.inAccumulatedThreshold),
            AmountCap.unwrap(policyStorage.outConstantThreshold),
            AmountCap.unwrap(policyStorage.outAccumulatedThreshold)
        );
    }

    /// @notice Retrieves the resolved policy thresholds for a given vault.
    /// @param vault The address of the vault.
    /// @return inConstantThreshold The constant threshold for incoming transfers.
    /// @return inAccumulatedThreshold The accumulated threshold for incoming transfers.
    /// @return outConstantThreshold The constant threshold for outgoing transfers.
    /// @return outAccumulatedThreshold The accumulated threshold for outgoing transfers.
    function getPolicyThresholdsResolved(address vault) external view returns (uint256, uint256, uint256, uint256) {
        PolicyStorage storage policyStorage = policies[vault];
        return (
            policyStorage.inConstantThreshold.resolve(),
            policyStorage.inAccumulatedThreshold.resolve(),
            policyStorage.outConstantThreshold.resolve(),
            policyStorage.outAccumulatedThreshold.resolve()
        );
    }

    /// @notice Saves an attestation.
    /// @param attestation The attestation data.
    /// @param attestationSignature The signature of the attestation.
    function saveAttestation(ISecurityValidator.Attestation calldata attestation, bytes calldata attestationSignature)
        external
    {
        validator.saveAttestation(attestation, attestationSignature);
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function deposit(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(IEVault(msg.sender).asset()).balanceOf(caller());
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function mint(uint256 amount, address receiver) external returns (uint256) {
        amount = IEVault(msg.sender).convertToAssets(amount);
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function skim(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) {
            uint256 balance = IEVault(IEVault(msg.sender).asset()).balanceOf(msg.sender);
            uint256 cash = IEVault(msg.sender).cash();
            amount = balance > cash ? balance - cash : 0;
        }
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256) {
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function redeem(uint256 amount, address receiver, address owner) external returns (uint256) {
        if (amount == type(uint256).max) {
            amount = IEVault(msg.sender).convertToAssets(IEVault(msg.sender).balanceOf(owner));
        }
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver, owner));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function borrow(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).cash();
        executeCheckpoint(TransferType.Out, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function repay(uint256 amount, address receiver) external returns (uint256) {
        if (amount == type(uint256).max) amount = IEVault(msg.sender).debtOf(receiver);
        executeCheckpoint(TransferType.In, amount, abi.encode(receiver));
        return 0;
    }

    /// @notice Overriden function of IEVault in order to be intercepted by the hook target.
    function checkVaultStatus() external view returns (bytes4) {
        validator.validateFinalState();
        return 0;
    }

    /// @notice Executes a checkpoint for a given transfer type and reference amount.
    /// @param transferType The type of transfer (In or Out).
    /// @param referenceAmount The reference amount for the transfer.
    /// @param hashable Additional data to be hashed.
    function executeCheckpoint(TransferType transferType, uint256 referenceAmount, bytes memory hashable) internal {
        address sender = caller();
        uint256 operationCounter = updateOperationCounter(sender);
        uint256 accumulatedAmount = updateAccumulatedAmount(transferType, msg.sender, referenceAmount);
        (uint256 constantThreshold, uint256 accumulatedThreshold) = resolveThresholds(msg.sender, transferType);

        if (
            (referenceAmount >= constantThreshold || accumulatedAmount >= accumulatedThreshold)
                && !evc.isSimulationInProgress()
        ) {
            // to prevent replay attacks, the hash must depend on:
            // - the vault address that is a caller of the hook target
            // - the operation type executed (function selector)
            // - the quantized reference amount that allows for runtime changes within an acceptable range
            // - the static parameters of the operation
            // - the authenticated account that executes the operation
            // - the operation counter associated with the authenticated account
            validator.executeCheckpoint(
                keccak256(
                    abi.encode(
                        msg.sender,
                        bytes4(msg.data),
                        log1_01(int256(referenceAmount)),
                        hashable,
                        sender,
                        operationCounter
                    )
                )
            );

            // this check must be done after the checkpoint is executed so that at this point, in case the
            // storeAttestation function is used instead of the saveAttestation function, the current attester must be
            // already defined by the validator contract
            if (!isAttestationInProgress()) {
                revert HTA_Unauthorized();
            }
        }
    }

    /// @notice Updates the operation counter for a given account.
    /// @param account The account for which the operation counter is updated.
    /// @return The updated operation counter.
    function updateOperationCounter(address account) internal returns (uint256) {
        bytes19 prefix = _getAddressPrefix(account);
        uint256 counter = operationCounters[prefix] + 1;
        operationCounters[prefix] = counter;
        return counter;
    }

    /// @notice Updates the accumulated amount for a given transfer type and vault.
    /// @param transferType The type of transfer (In or Out).
    /// @param vault The vault address.
    /// @param referenceAmount The reference amount for the transfer.
    /// @return The updated accumulated amount.
    function updateAccumulatedAmount(TransferType transferType, address vault, uint256 referenceAmount)
        internal
        returns (uint256)
    {
        StorageSlot.Uint256SlotType slot = StorageSlot.asUint256(keccak256(abi.encode(transferType, vault)));
        uint256 accumulatedAmount = StorageSlot.tload(slot) + referenceAmount;
        StorageSlot.tstore(slot, accumulatedAmount);
        return accumulatedAmount;
    }

    /// @notice Checks if an attestation is in progress.
    /// @return True if an attestation is in progress, false otherwise.
    function isAttestationInProgress() internal view returns (bool) {
        address currentAttester = validator.getCurrentAttester();
        return currentAttester != address(0) && policies[msg.sender].attesters.contains(currentAttester);
    }

    /// @notice Resolves the constant and accumulated thresholds for a given vault and transfer type.
    /// @param vault The address of the vault.
    /// @param transferType The type of transfer (In or Out).
    /// @return constantThreshold The resolved constant threshold.
    /// @return accumulatedThreshold The resolved accumulated threshold.
    function resolveThresholds(address vault, TransferType transferType)
        internal
        view
        returns (uint256 constantThreshold, uint256 accumulatedThreshold)
    {
        PolicyStorage storage policy = policies[vault];

        if (transferType == TransferType.In) {
            constantThreshold = policy.inConstantThreshold.resolve();
            accumulatedThreshold = policy.inAccumulatedThreshold.resolve();
        } else {
            constantThreshold = policy.outConstantThreshold.resolve();
            accumulatedThreshold = policy.outAccumulatedThreshold.resolve();
        }
    }

    /// @notice Calculates the logarithm base 1.01 of a given number.
    /// @param x The number to calculate the logarithm for.
    /// @return The logarithm base 1.01 of the given number.
    function log1_01(int256 x) internal pure returns (int256) {
        if (x == 0) return type(int256).max;

        // log1.01(x) = ln(x) / ln(1.01) = lnWad(x * 1e18) / lnWad(1.01 * 1e18)
        return FixedPointMathLib.lnWad(x * 1e18) / 9950330853168082;
    }

    /// @notice Retrieves the caller address from the calldata.
    /// @return _caller The address of the caller.
    function caller() internal pure returns (address _caller) {
        assembly {
            _caller := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}
