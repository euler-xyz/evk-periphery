// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {HookTargetFirewall, ISecurityValidator} from "../../src/HookTarget/HookTargetFirewall.sol";
import "evk/EVault/shared/Constants.sol";

contract HookTargetFirewallTest is EVaultTestBase {
    ISecurityValidator internal securityValidator;
    HookTargetFirewall internal hookTarget;

    function setUp() public virtual override {
        super.setUp();

        string memory FORK_RPC_URL = vm.envOr("FORK_RPC_URL", string(""));
        if (bytes(FORK_RPC_URL).length != 0) vm.createSelectFork(FORK_RPC_URL);

        securityValidator = ISecurityValidator(0xc9b1AeD0895Dd647A82e35Cafff421B6CcFe690C);
        hookTarget =
            new HookTargetFirewall(address(evc), address(factory), address(securityValidator), keccak256("test"));

        eTST.setHookConfig(
            address(hookTarget),
            OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_BORROW | OP_REPAY | OP_VAULT_STATUS_CHECK
        );

        eTST2.setHookConfig(
            address(hookTarget),
            OP_DEPOSIT | OP_MINT | OP_WITHDRAW | OP_REDEEM | OP_SKIM | OP_BORROW | OP_REPAY | OP_VAULT_STATUS_CHECK
        );
    }

    function log1_01(uint256 x) internal pure returns (uint256) {
        if (x == 0) return type(uint256).max;

        // log1.01(x) = ln(x) / ln(1.01) = lnWad(x * 1e18) / lnWad(1.01 * 1e18)
        return uint256(FixedPointMathLib.lnWad(int256(x * 1e18))) / 9950330853168082;
    }

    function test_isHookTarget() public {
        GenericFactory unrecognizedFactory = new GenericFactory(admin);
        address eVaultImpl = factory.implementation();

        vm.prank(admin);
        unrecognizedFactory.setImplementation(eVaultImpl);

        IEVault unrecognizedEVault = IEVault(
            unrecognizedFactory.createProxy(
                address(0), true, abi.encodePacked(address(assetTST), address(0), address(0))
            )
        );

        vm.expectRevert();
        unrecognizedEVault.setHookConfig(address(hookTarget), 1);
    }

    function test_saveAttestation(
        uint256 privateKey,
        uint40 timestamp,
        uint40 timeout,
        bytes32[] memory executionHashes
    ) public {
        vm.assume(
            privateKey > 0
                && privateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(uint256(timestamp) + uint256(timeout) <= type(uint40).max);
        vm.warp(timestamp);

        address attester = vm.addr(privateKey);
        ISecurityValidator.Attestation memory attestation =
            ISecurityValidator.Attestation({deadline: timestamp + timeout, executionHashes: executionHashes});

        bytes32 hashOfAttestation = securityValidator.hashAttestation(attestation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashOfAttestation);

        uint256 snapshot = vm.snapshot();
        hookTarget.saveAttestation(attestation, abi.encodePacked(r, s, v));
        assertEq(securityValidator.getCurrentAttester(), attester);

        // incorrect signature
        vm.revertTo(snapshot);
        r = keccak256(abi.encode(r));
        try hookTarget.saveAttestation(attestation, abi.encodePacked(r, s, v)) {
            assertNotEq(securityValidator.getCurrentAttester(), attester);
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(ECDSA.ECDSAInvalidSignature.selector));
        }
    }

    function test_governanceFunctions(
        address vault,
        address governor,
        address firstAttester,
        uint8 numberOfAttesters,
        uint16[] memory thresholds
    ) public {
        vm.assume(uint160(vault) > 255 && vault.code.length == 0 && vault != governor);
        vm.assume(governor != address(0) && governor != address(evc) && governor != address(this));
        vm.assume(firstAttester != address(0));
        vm.assume(numberOfAttesters > 0 && numberOfAttesters <= 10);
        vm.assume(thresholds.length >= 5);
        vm.etch(vault, address(eTST).code);
        address attester = firstAttester;

        // if non-governor calling, revert
        vm.startPrank(governor);
        vm.expectRevert();
        hookTarget.addPolicyAttester(vault, attester);
        vm.expectRevert();
        hookTarget.removePolicyAttester(vault, attester);
        vm.expectRevert();
        hookTarget.setAllowTrustedOrigin(vault, true);
        vm.expectRevert();
        hookTarget.setPolicyThresholds(vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4]);
        vm.stopPrank();

        // set governor admin
        vm.prank(address(0));
        IEVault(vault).setGovernorAdmin(governor);

        // succeeds if governor is calling
        uint256 snapshot = vm.snapshot();
        vm.startPrank(governor);
        hookTarget.addPolicyAttester(vault, attester);
        hookTarget.removePolicyAttester(vault, attester);
        hookTarget.setAllowTrustedOrigin(vault, true);
        hookTarget.setPolicyThresholds(vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4]);
        vm.stopPrank();

        // succeeds if governor is calling also through the EVC
        vm.revertTo(snapshot);
        vm.startPrank(governor);
        evc.call(address(hookTarget), governor, 0, abi.encodeCall(hookTarget.addPolicyAttester, (vault, attester)));
        evc.call(address(hookTarget), governor, 0, abi.encodeCall(hookTarget.removePolicyAttester, (vault, attester)));
        evc.call(
            address(hookTarget),
            governor,
            0,
            abi.encodeCall(hookTarget.setAllowTrustedOrigin, (vault, true))
        );
        evc.call(
            address(hookTarget),
            governor,
            0,
            abi.encodeCall(
                hookTarget.setPolicyThresholds,
                (vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4])
            )
        );
        vm.stopPrank();

        // but fails if non-governor is calling through the EVC, i.e. if governor's sub-account
        {
            vm.revertTo(snapshot);
            vm.startPrank(governor);
            address governorsSubAccount = address(uint160(governor) ^ 1);
            vm.expectRevert();
            evc.call(
                address(hookTarget),
                governorsSubAccount,
                0,
                abi.encodeCall(hookTarget.addPolicyAttester, (vault, attester))
            );
            vm.expectRevert();
            evc.call(
                address(hookTarget),
                governorsSubAccount,
                0,
                abi.encodeCall(hookTarget.setAllowTrustedOrigin, (vault, true))
            );
            vm.expectRevert();
            evc.call(
                address(hookTarget),
                governorsSubAccount,
                0,
                abi.encodeCall(hookTarget.removePolicyAttester, (vault, attester))
            );
            vm.expectRevert();
            evc.call(
                address(hookTarget),
                governorsSubAccount,
                0,
                abi.encodeCall(
                    hookTarget.setPolicyThresholds,
                    (vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4])
                )
            );
            vm.stopPrank();
        }

        // succeeds if governor is calling, verify the outcome
        vm.revertTo(snapshot);
        for (uint256 i = 0; i < numberOfAttesters; ++i) {
            vm.expectEmit(true, true, true, true);
            emit HookTargetFirewall.AddPolicyAttester(vault, attester);
            vm.prank(governor);
            hookTarget.addPolicyAttester(vault, attester);

            {
                bool found;
                address[] memory attesters = hookTarget.getPolicyAttesters(vault);
                for (uint256 j = 0; j < attesters.length; ++j) {
                    if (attesters[j] == attester) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found);
            }

            vm.expectEmit(true, true, true, true);
            emit HookTargetFirewall.SetAllowTrustedOrigin(vault, true);
            vm.prank(governor);
            hookTarget.setAllowTrustedOrigin(vault, true);
            assertEq(hookTarget.getAllowTrustedOrigin(vault), true);

            vm.expectEmit(true, true, true, true);
            emit HookTargetFirewall.SetAllowTrustedOrigin(vault, false);
            vm.prank(governor);
            hookTarget.setAllowTrustedOrigin(vault, false);
            assertEq(hookTarget.getAllowTrustedOrigin(vault), false);

            vm.expectEmit(true, true, true, true);
            emit HookTargetFirewall.SetPolicyThresholds(
                vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4]
            );
            vm.prank(governor);
            hookTarget.setPolicyThresholds(
                vault, thresholds[0], thresholds[1], thresholds[2], thresholds[3], thresholds[4]
            );
            (uint32 th0, uint16 th1, uint16 th2, uint16 th3, uint16 th4) = hookTarget.getPolicyThresholds(vault);
            assertEq(th0, thresholds[0]);
            assertEq(th1, thresholds[1]);
            assertEq(th2, thresholds[2]);
            assertEq(th3, thresholds[3]);
            assertEq(th4, thresholds[4]);

            attester = address(uint160(uint256(keccak256(abi.encode(attester)))));
        }

        attester = firstAttester;
        for (uint256 i = 0; i < numberOfAttesters; ++i) {
            vm.expectEmit(true, true, true, true);
            emit HookTargetFirewall.RemovePolicyAttester(vault, attester);
            vm.prank(governor);
            hookTarget.removePolicyAttester(vault, attester);

            bool found;
            address[] memory attesters = hookTarget.getPolicyAttesters(vault);
            for (uint256 j = 0; j < attesters.length; ++j) {
                if (attesters[j] == attester) {
                    found = true;
                    break;
                }
            }
            assertFalse(found);

            attester = address(uint160(uint256(keccak256(abi.encode(attester)))));
        }
    }

    function test_deposit() public {
        vm.warp(100);

        uint256 privateKey = 1;
        address attester = vm.addr(privateKey);
        address receiver = vm.addr(privateKey + 1);
        uint256 amount = 1e18;
        uint16 amountThreshold = assetTST.decimals() | 100 << 6;
        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.addPolicyAttester(address(eTST), attester);
        assetTST.mint(address(this), type(uint112).max);
        assetTST.approve(address(eTST), type(uint112).max);

        // no thresholds are set, operation succeeds without attestation
        uint256 snapshot = vm.snapshot();
        eTST.deposit(amount, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // operation counter threshold is set, operation fails without attestation
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        vm.expectRevert();
        eTST.deposit(amount, receiver);

        // out amount thresholds are set, operation succeeds without attestation
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, 1, 1);
        eTST.deposit(amount, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // in amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, amountThreshold, 0, 0, 0);
        eTST.deposit(amount - 1, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // in amount threshold is set, operation fails because the amount is at the threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, amountThreshold, 0, 0, 0);
        vm.expectRevert();
        eTST.deposit(amount, receiver);

        // in amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, amountThreshold, 0, 0);
        eTST.deposit(amount - 1, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // operation counter threshold and in amount threshold are set, operation fails without attestation even though
        // the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, amountThreshold, 0, 0);
        vm.expectRevert();
        eTST.deposit(amount - 1, receiver);

        // in amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, amountThreshold, 0, 0);
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (amount / 2, receiver))
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (amount / 2 - 1, receiver))
        });
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // operation counter threshold and in amount threshold are set, operation fails without attestation even though
        // the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, amountThreshold, 0, 0);
        vm.expectRevert();
        evc.batch(items);

        // however, the operation succeeds if simulated (no attestation required)
        {
            vm.revertTo(snapshot);
            hookTarget.setPolicyThresholds(address(eTST), 1, 0, amountThreshold, 0, 0);
            (IEVC.BatchItemResult[] memory batchItemsResult,, IEVC.StatusCheckResult[] memory vaultStatusCheckResult) =
                evc.batchSimulation(items);
            assertEq(batchItemsResult[0].success, true);
            assertEq(batchItemsResult[1].success, true);
            assertEq(vaultStatusCheckResult[0].isValid, true);
        }

        // in amount threshold is set, operation fails because the amount is at the threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, amountThreshold, 0, 0);
        items[1] = items[0];
        vm.expectRevert();
        evc.batch(items);

        // however, the operation succeeds if simulated (no attestation required)
        {
            vm.revertTo(snapshot);
            hookTarget.setPolicyThresholds(address(eTST), 0, 0, amountThreshold, 0, 0);
            (IEVC.BatchItemResult[] memory batchItemsResult,, IEVC.StatusCheckResult[] memory vaultStatusCheckResult) =
                evc.batchSimulation(items);
            assertEq(batchItemsResult[0].success, true);
            assertEq(batchItemsResult[1].success, true);
            assertEq(vaultStatusCheckResult[0].isValid, true);
        }

        // in amount threshold is set, operation fails because the attestation provided is incorrect
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, amountThreshold, 0, 0);
        snapshot = vm.snapshot();

        ISecurityValidator.Attestation memory attestation;
        attestation.deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items = new IEVC.BatchItem[](3);
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (amount / 2, receiver))
        });
        items[2] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (amount / 2, receiver))
        });
        vm.expectRevert();
        evc.batch(items);

        // operation fails because the attestation provided is signed by the wrong attester
        vm.revertTo(snapshot);
        attestation.executionHashes = new bytes32[](1);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            // execution hash as per HookTargetFirewall
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.deposit.selector),
                    log1_01(amount / 2),
                    abi.encode(receiver),
                    address(this),
                    2
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );

        (v, r, s) = vm.sign(privateKey + 1, securityValidator.hashAttestation(attestation));
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        vm.expectRevert();
        evc.batch(items);

        // operation succeeds now because the attestation provided is correct
        vm.revertTo(snapshot);

        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // operation fails if the attestation signature is replayed
        vm.expectRevert();
        evc.batch(items);

        // operation still succeeds even if the reference amount differs slightly
        vm.revertTo(snapshot);
        items[2].data = abi.encodeCall(eTST.deposit, (1001 * (amount / 2) / 1000, receiver));
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // but operation fails if the reference amount differs significantly
        vm.revertTo(snapshot);
        items[2].data = abi.encodeCall(eTST.deposit, (101 * (amount / 2) / 100, receiver));
        vm.expectRevert();
        evc.batch(items);

        // operation succeeds with attestation saved in a separate tx
        vm.revertTo(snapshot);
        vm.startPrank(address(this), address(this));
        securityValidator.storeAttestation(attestation, abi.encodePacked(r, s, v));
        items[0] = IEVC.BatchItem({targetContract: address(0), onBehalfOfAccount: address(this), value: 0, data: ""});
        items[2].data = abi.encodeCall(eTST.deposit, (amount / 2, receiver));
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // elapse 1 minute
        vm.warp(100 + 1 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // elapse another 1 minute
        vm.warp(100 + 2 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // elapse another 1 minute
        vm.warp(100 + 3 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 0);
    }

    function test_withdraw() public {
        vm.warp(100);

        uint256 privateKey = 1;
        address attester = vm.addr(privateKey);
        address receiver = vm.addr(privateKey + 1);
        uint256 amount = 1e18;
        uint16 amountThreshold = assetTST.decimals() | 100 << 6;
        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.addPolicyAttester(address(eTST), attester);
        assetTST.mint(address(this), type(uint112).max);
        assetTST.approve(address(eTST), type(uint112).max);

        // deposit first and elapse 1 minute
        eTST.deposit(type(uint112).max, address(this));
        vm.warp(100 + 1 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // no thresholds are set, operation succeeds without attestation
        uint256 snapshot = vm.snapshot();
        eTST.withdraw(amount, receiver, address(this));
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // operation counter threshold is set, operation fails without attestation
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        vm.expectRevert();
        eTST.withdraw(amount, receiver, address(this));

        // in amount threshold is set, operation succeeds without attestation
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 1, 1, 0, 0);
        eTST.withdraw(amount, receiver, address(this));
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // out amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, amountThreshold, 0);
        eTST.withdraw(amount - 1, receiver, address(this));
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // out amount threshold is set, operation fails because the amount is at the threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, amountThreshold, 0);
        vm.expectRevert();
        eTST.withdraw(amount, receiver, address(this));

        // out amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, amountThreshold, 0);
        eTST.withdraw(amount - 1, receiver, address(this));
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // operation counter threshold and out amount threshold are set, operation fails without attestation even though
        // the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, amountThreshold, 0);
        vm.expectRevert();
        eTST.withdraw(amount - 1, receiver, address(this));

        // out amount threshold is set, operation succeeds without attestation because the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, amountThreshold, 0);
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.withdraw, (amount / 2, receiver, address(this)))
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.withdraw, (amount / 2 - 1, receiver, address(this)))
        });
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 3);

        // operation counter threshold and out amount threshold are set, operation fails without attestation even though
        // the amount is below threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, amountThreshold);
        vm.expectRevert();
        evc.batch(items);

        // however, the operation succeeds if simulated (no attestation required)
        {
            vm.revertTo(snapshot);
            hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, amountThreshold);
            (IEVC.BatchItemResult[] memory batchItemsResult,, IEVC.StatusCheckResult[] memory vaultStatusCheckResult) =
                evc.batchSimulation(items);
            assertEq(batchItemsResult[0].success, true);
            assertEq(batchItemsResult[1].success, true);
            assertEq(vaultStatusCheckResult[0].isValid, true);
        }

        // out amount threshold is set, operation fails because the amount is at the threshold
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, 0, amountThreshold);
        items[1] = items[0];
        vm.expectRevert();
        evc.batch(items);

        // however, the operation succeeds if simulated (no attestation required)
        {
            vm.revertTo(snapshot);
            hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, 0, amountThreshold);
            (IEVC.BatchItemResult[] memory batchItemsResult,,) = evc.batchSimulation(items);
            assertEq(batchItemsResult[0].success, true);
            assertEq(batchItemsResult[1].success, true);
        }

        // out amount threshold is set, operation fails because the attestation provided is incorrect
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, 0, amountThreshold);
        snapshot = vm.snapshot();

        ISecurityValidator.Attestation memory attestation;
        attestation.deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items = new IEVC.BatchItem[](3);
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.withdraw, (amount / 2, receiver, address(this)))
        });
        items[2] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.withdraw, (amount / 2, receiver, address(this)))
        });
        vm.expectRevert();
        evc.batch(items);

        // operation fails because the attestation provided is signed by the wrong attester
        vm.revertTo(snapshot);
        attestation.executionHashes = new bytes32[](1);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            // execution hash as per HookTargetFirewall
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.withdraw.selector),
                    log1_01(amount / 2),
                    abi.encode(receiver, address(this)),
                    address(this),
                    3
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );

        (v, r, s) = vm.sign(privateKey + 1, securityValidator.hashAttestation(attestation));
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        vm.expectRevert();
        evc.batch(items);

        // operation succeeds now because the attestation provided is correct
        vm.revertTo(snapshot);

        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // operation fails if the attestation signature is replayed
        vm.expectRevert();
        evc.batch(items);

        // operation still succeeds even if the reference amount differs slightly
        vm.revertTo(snapshot);
        items[2].data = abi.encodeCall(eTST.withdraw, (1001 * (amount / 2) / 1000, receiver, address(this)));
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // but operation fails if the reference amount differs significantly
        vm.revertTo(snapshot);
        items[2].data = abi.encodeCall(eTST.withdraw, (101 * (amount / 2) / 100, receiver, address(this)));
        vm.expectRevert();
        evc.batch(items);

        // operation succeeds with attestation saved in a separate tx
        vm.revertTo(snapshot);
        vm.startPrank(address(this), address(this));
        securityValidator.storeAttestation(attestation, abi.encodePacked(r, s, v));
        items[0] = IEVC.BatchItem({targetContract: address(0), onBehalfOfAccount: address(this), value: 0, data: ""});
        items[2].data = abi.encodeCall(eTST.withdraw, (amount / 2, receiver, address(this)));
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // elapse 1 minute
        vm.warp(100 + 2 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

        // elapse another 1 minute
        vm.warp(100 + 3 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // elapse another 1 minute
        vm.warp(100 + 4 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 0);
    }

    function test_complexScenario() public {
        vm.warp(100);

        uint256 privateKey = 1;
        address attester = vm.addr(privateKey);
        address subAccountOne = address(uint160(address(this)) ^ 1);

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        eTST.setLTV(address(eTST2), 0.5e4, 0.5e4, 0);

        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.setAllowTrustedOrigin(address(eTST2), true);
        hookTarget.addPolicyAttester(address(eTST), address(0));
        hookTarget.addPolicyAttester(address(eTST), address(1));
        hookTarget.addPolicyAttester(address(eTST), attester);
        hookTarget.addPolicyAttester(address(eTST2), address(0));
        hookTarget.addPolicyAttester(address(eTST2), address(1));
        hookTarget.addPolicyAttester(address(eTST2), attester);

        // operationCounterThreshold = 3 for eTST and 4 for eTST2
        // inConstantAmountThreshold = 3e18
        // inAccumulatedAmountThreshold = 4e18
        // outConstantAmountThreshold = 1e18
        // outAccumulatedAmountThreshold = 2e18
        hookTarget.setPolicyThresholds(address(eTST), 3, 18 | 300 << 6, 18 | 400 << 6, 18 | 100 << 6, 18 | 200 << 6);
        hookTarget.setPolicyThresholds(address(eTST2), 4, 18 | 300 << 6, 18 | 400 << 6, 18 | 100 << 6, 18 | 200 << 6);

        assetTST.mint(address(this), type(uint112).max);
        assetTST2.mint(address(this), type(uint112).max);
        assetTST.approve(address(eTST), type(uint112).max);
        assetTST2.approve(address(eTST2), type(uint112).max);

        // - save the attestation
        // - deposit 2.5e18 of assetTST
        // - deposit 2.5e18 of assetTST - executes checkpoint
        // - deposit 5e18 of assetTST2 - executes checkpoint
        // - borrow 1e18 of assetTST - executes checkpoint
        // - borrow 0.5e18 of assetTST
        // - withdraw 0.5e18 of assetTST2
        // - withdraw 0.5e18 of assetTST2
        // - withdraw 0.5e18 of assetTST2
        // - withdraw 0.5e18 of assetTST2 - executes checkpoint
        // - repay 1.5e18 of assetTST - executes checkpoint
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](12);
        items[0] = IEVC.BatchItem({
            targetContract: address(0),
            onBehalfOfAccount: address(this),
            value: 0,
            data: "ff" // dummy call. this batch item is a placeholder for the attestation added later on
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (2.5e18, address(this)))
        });
        items[2] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (2.5e18, address(this)))
        });
        items[3] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (5e18, subAccountOne))
        });
        items[4] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeCall(evc.enableController, (subAccountOne, address(eTST)))
        });
        items[5] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST.borrow, (1e18, address(this)))
        });
        items[6] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST.borrow, (0.5e18, address(this)))
        });
        items[7] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST2.withdraw, (0.5e18, address(this), subAccountOne))
        });
        items[8] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST2.withdraw, (0.5e18, address(this), subAccountOne))
        });
        items[9] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST2.withdraw, (0.5e18, address(this), subAccountOne))
        });
        items[10] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: subAccountOne,
            value: 0,
            data: abi.encodeCall(eTST2.withdraw, (0.5e18, address(this), subAccountOne))
        });
        items[11] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.repay, (1.5e18, subAccountOne))
        });

        // fails without the attestation
        vm.expectRevert();
        evc.batch(items);

        // but it is possible to simulate without the attestation
        {
            (
                IEVC.BatchItemResult[] memory batchItemsResult,
                IEVC.StatusCheckResult[] memory accountsStatusCheckResult,
                IEVC.StatusCheckResult[] memory vaultStatusCheckResult
            ) = evc.batchSimulation(items);
            for (uint256 i = 0; i < batchItemsResult.length; i++) {
                assertEq(batchItemsResult[i].success, true);
            }
            for (uint256 i = 0; i < accountsStatusCheckResult.length; i++) {
                assertEq(accountsStatusCheckResult[i].isValid, true);
            }
            for (uint256 i = 0; i < vaultStatusCheckResult.length; i++) {
                assertEq(vaultStatusCheckResult[i].isValid, true);
            }
        }

        // prepare the attestation
        ISecurityValidator.Attestation memory attestation;
        attestation.deadline = block.timestamp;
        attestation.executionHashes = new bytes32[](5);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.deposit.selector),
                    log1_01(2.5e18),
                    abi.encode(address(this)),
                    address(this),
                    2
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        attestation.executionHashes[1] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST2),
                    bytes4(eTST.deposit.selector),
                    log1_01(5e18),
                    abi.encode(subAccountOne),
                    address(this),
                    3
                )
            ),
            address(hookTarget),
            attestation.executionHashes[0]
        );
        attestation.executionHashes[2] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.borrow.selector),
                    log1_01(1e18),
                    abi.encode(address(this)),
                    subAccountOne,
                    4
                )
            ),
            address(hookTarget),
            attestation.executionHashes[1]
        );
        attestation.executionHashes[3] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST2),
                    bytes4(eTST.withdraw.selector),
                    log1_01(0.5e18),
                    abi.encode(address(this), subAccountOne),
                    subAccountOne,
                    9
                )
            ),
            address(hookTarget),
            attestation.executionHashes[2]
        );
        attestation.executionHashes[4] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.repay.selector),
                    log1_01(1.5e18),
                    abi.encode(subAccountOne),
                    address(this),
                    10
                )
            ),
            address(hookTarget),
            attestation.executionHashes[3]
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });

        // succeeds with the attestation
        uint256 snapshot = vm.snapshot();
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);
        assertEq(hookTarget.getOperationCounter(address(eTST2)), 3);

        // not possible to replay
        vm.expectRevert();
        evc.batch(items);

        // additional operation below the threshold requires an attestation due to the operationCounterThreshold
        // exceeded
        vm.expectRevert();
        eTST.deposit(0, address(0));

        vm.expectRevert();
        eTST2.deposit(0, address(0));

        {
            // additional operations now succeed with a new attestation
            ISecurityValidator.Attestation memory newAttestation;
            newAttestation.deadline = block.timestamp;
            newAttestation.executionHashes = new bytes32[](1);
            newAttestation.executionHashes[0] = securityValidator.executionHashFrom(
                keccak256(
                    abi.encode(
                        address(eTST),
                        bytes4(eTST.deposit.selector),
                        log1_01(0),
                        abi.encode(address(0)),
                        address(this),
                        11
                    )
                ),
                address(hookTarget),
                bytes32(uint256(0))
            );
            (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(newAttestation));

            IEVC.BatchItem[] memory newItems = new IEVC.BatchItem[](2);
            newItems[0] = IEVC.BatchItem({
                targetContract: address(hookTarget),
                onBehalfOfAccount: address(this),
                value: 0,
                data: abi.encodeCall(HookTargetFirewall.saveAttestation, (newAttestation, abi.encodePacked(r, s, v)))
            });
            newItems[1] = IEVC.BatchItem({
                targetContract: address(eTST),
                onBehalfOfAccount: address(this),
                value: 0,
                data: abi.encodeCall(eTST.deposit, (0, address(0)))
            });
            evc.batch(newItems);
            assertEq(hookTarget.getOperationCounter(address(eTST)), 2);

            newAttestation.executionHashes[0] = securityValidator.executionHashFrom(
                keccak256(
                    abi.encode(
                        address(eTST2),
                        bytes4(eTST.deposit.selector),
                        log1_01(0),
                        abi.encode(address(0)),
                        address(this),
                        12
                    )
                ),
                address(hookTarget),
                bytes32(uint256(0))
            );
            (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(newAttestation));

            vm.prank(address(this), address(this));
            securityValidator.storeAttestation(newAttestation, abi.encodePacked(r, s, v));

            vm.prank(address(this), address(this));
            eTST2.deposit(0, address(0));
            assertEq(hookTarget.getOperationCounter(address(eTST2)), 3);
        }

        // the amounts can be floating a bit
        vm.revertTo(snapshot);
        items[1].data = abi.encodeCall(eTST.deposit, (2.5e18 + 1000, address(this)));
        items[2].data = abi.encodeCall(eTST.deposit, (2.5e18 - 1000, address(this)));
        items[3].data = abi.encodeCall(eTST.deposit, (5e18 - 10000, subAccountOne));
        items[5].data = abi.encodeCall(eTST.borrow, (1e18 + 10000, address(this)));
        items[6].data = abi.encodeCall(eTST.borrow, (0.5e18 + 10000, address(this)));
        items[7].data = abi.encodeCall(eTST.withdraw, (0.5e18 - 1000, address(this), subAccountOne));
        items[8].data = abi.encodeCall(eTST.withdraw, (0.5e18 - 1000, address(this), subAccountOne));
        items[9].data = abi.encodeCall(eTST.withdraw, (0.5e18 + 1000, address(this), subAccountOne));
        items[10].data = abi.encodeCall(eTST.withdraw, (0.5e18 + 1000, address(this), subAccountOne));
        items[11].data = abi.encodeCall(eTST.repay, (type(uint256).max, subAccountOne));
        evc.batch(items);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 2);
        assertEq(hookTarget.getOperationCounter(address(eTST2)), 3);

        // fails if the attestation not fully utilized
        {
            vm.revertTo(snapshot);
            IEVC.BatchItem[] memory itemsSubset = new IEVC.BatchItem[](4);
            for (uint256 i = 0; i < 4; i++) {
                itemsSubset[i] = items[i];
            }
            vm.expectRevert();
            evc.batch(itemsSubset);
        }
    }

    function test_trustedOrigin() public {
        vm.warp(100);

        address trustedOrigin = makeAddr("TRUSTED_ORIGIN");
        address receiver = makeAddr("RECEIVER");
        uint256 amount = 1e18;
        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.addPolicyAttester(address(eTST), trustedOrigin);
        assetTST.mint(address(this), type(uint112).max);
        assetTST.approve(address(eTST), type(uint112).max);

        // no thresholds are set, operation succeeds without attestation
        uint256 snapshot = vm.snapshot();
        eTST.deposit(amount, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);

        // operation counter threshold is set, operation fails without attestation
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        vm.expectRevert();
        eTST.deposit(amount, receiver);

        // operation succeeds if the transaction is coming from the trusted origin and the allowTrustedOrigin flag is set
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        vm.prank(address(this), trustedOrigin);
        eTST.deposit(amount, receiver);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 0);

        // operation fails if the origin address is not trusted
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        hookTarget.removePolicyAttester(address(eTST), trustedOrigin);
        vm.prank(address(this), trustedOrigin);
        vm.expectRevert();
        eTST.deposit(amount, receiver);

        // operation fails if the allowTrustedOrigin flag is not set
        vm.revertTo(snapshot);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);
        hookTarget.setAllowTrustedOrigin(address(eTST), false);
        vm.prank(address(this), trustedOrigin);
        vm.expectRevert();
        eTST.deposit(amount, receiver);
    }

    function test_maxAmounts() public {
        vm.warp(100);

        uint256 privateKey = 1;
        address attester = vm.addr(privateKey);
        address subAccountOne = address(uint160(address(this)) ^ 1);

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        eTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);

        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.addPolicyAttester(address(eTST), attester);
        hookTarget.setPolicyThresholds(address(eTST), 0, 1, 1, 1, 1);
        eTST2.setHookConfig(address(0), 0);

        assetTST.mint(address(this), type(uint64).max);
        assetTST2.mint(address(this), type(uint64).max);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);

        // test the deposit max amount
        ISecurityValidator.Attestation memory attestation;
        attestation.deadline = block.timestamp;
        attestation.executionHashes = new bytes32[](1);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.deposit.selector),
                    log1_01(2 ** 64 - 1),
                    abi.encode(address(this)),
                    address(this),
                    1
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](2);
        items[0] = IEVC.BatchItem({
            targetContract: address(hookTarget),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)))
        });
        items[1] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(eTST.deposit, (type(uint256).max, address(this)))
        });
        evc.batch(items);

        // test the redeem max amount
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.redeem.selector),
                    log1_01(2 ** 64 - 1),
                    abi.encode(address(this), address(this)),
                    address(this),
                    2
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items[0].data = abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)));
        items[1].data = abi.encodeCall(eTST.redeem, (type(uint256).max, address(this), address(this)));
        evc.batch(items);

        // test the skim max amount
        assetTST.transfer(address(eTST), type(uint32).max);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.skim.selector),
                    log1_01(2 ** 32 - 1),
                    abi.encode(address(this)),
                    address(this),
                    3
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items[0].data = abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)));
        items[1].data = abi.encodeCall(eTST.skim, (type(uint256).max, address(this)));
        evc.batch(items);

        // test the borrow max amount
        evc.enableController(subAccountOne, address(eTST));
        evc.enableCollateral(subAccountOne, address(eTST2));
        eTST2.deposit(type(uint64).max, subAccountOne);

        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.borrow.selector),
                    log1_01(2 ** 32 - 1),
                    abi.encode(address(this)),
                    subAccountOne,
                    4
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items[0].data = abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)));
        items[1].onBehalfOfAccount = subAccountOne;
        items[1].data = abi.encodeCall(eTST.borrow, (type(uint256).max, address(this)));
        evc.batch(items);

        // test the repay max amount
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST),
                    bytes4(eTST.repay.selector),
                    log1_01(2 ** 32 - 1),
                    abi.encode(subAccountOne),
                    address(this),
                    5
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        items[0].data = abi.encodeCall(HookTargetFirewall.saveAttestation, (attestation, abi.encodePacked(r, s, v)));
        items[1].onBehalfOfAccount = address(this);
        items[1].data = abi.encodeCall(eTST.repay, (type(uint256).max, subAccountOne));
        evc.batch(items);
    }

    function test_unauthorizedCaller(address caller) public {
        vm.assume(caller != address(0) && !factory.isProxy(caller));

        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(HookTargetFirewall.HTA_Unauthorized.selector));
        hookTarget.deposit(0, address(0));

        // succeeds if function is called through the vault
        eTST.deposit(0, address(0));
        assertEq(hookTarget.getOperationCounter(address(eTST)), 1);
    }

    function test_vaultOperationCounters(uint32 timestamp, uint8 window1, uint8 window2, uint8 window3) public {
        vm.assume(timestamp != 0);
        vm.assume(window1 != 0 || window2 != 0 || window3 != 0);
        hookTarget.setPolicyThresholds(address(eTST), 0, 0, 0, 0, 0);

        vm.warp(timestamp);
        for (uint256 i = 0; i < window1; i++) {
            eTST.deposit(0, address(0));
            assertEq(hookTarget.getOperationCounter(address(eTST)), i + 1);
        }

        vm.warp(uint256(timestamp) + 1 minutes);
        for (uint256 i = 0; i < window2; i++) {
            eTST.deposit(0, address(0));
            assertEq(hookTarget.getOperationCounter(address(eTST)), uint256(window1) + i + 1);
        }

        vm.warp(uint256(timestamp) + 2 minutes);
        for (uint256 i = 0; i < window3; i++) {
            eTST.deposit(0, address(0));
            assertEq(hookTarget.getOperationCounter(address(eTST)), uint256(window1) + uint256(window2) + i + 1);
        }
        assertEq(hookTarget.getOperationCounter(address(eTST)), uint256(window1) + uint256(window2) + uint256(window3));

        hookTarget.setPolicyThresholds(address(eTST), uint32(window1) + uint32(window2) + uint32(window3), 0, 0, 0, 0);
        vm.expectRevert();
        eTST.deposit(0, address(0));

        vm.warp(uint256(timestamp) + 3 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), uint256(window2) + uint256(window3));

        vm.warp(uint256(timestamp) + 4 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), uint256(window3));

        vm.warp(uint256(timestamp) + 5 minutes);
        assertEq(hookTarget.getOperationCounter(address(eTST)), 0);
    }

    function test_multipleAttestationsInOneTx() public {
        vm.warp(1);

        uint256 privateKey = 1;
        address attester = vm.addr(privateKey);
        hookTarget.setAllowTrustedOrigin(address(eTST), true);
        hookTarget.addPolicyAttester(address(eTST), attester);
        hookTarget.setPolicyThresholds(address(eTST), 1, 0, 0, 0, 0);

        vm.startPrank(address(this), address(this));
        ISecurityValidator.Attestation memory attestation;
        attestation.deadline = block.timestamp;
        attestation.executionHashes = new bytes32[](1);
        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST), bytes4(eTST.deposit.selector), log1_01(0), abi.encode(address(0)), address(this), 1
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        securityValidator.storeAttestation(attestation, abi.encodePacked(r, s, v));
        eTST.deposit(0, address(0));

        attestation.executionHashes[0] = securityValidator.executionHashFrom(
            keccak256(
                abi.encode(
                    address(eTST), bytes4(eTST.deposit.selector), log1_01(0), abi.encode(address(0)), address(this), 2
                )
            ),
            address(hookTarget),
            bytes32(uint256(0))
        );
        (v, r, s) = vm.sign(privateKey, securityValidator.hashAttestation(attestation));

        securityValidator.storeAttestation(attestation, abi.encodePacked(r, s, v));
        eTST.deposit(0, address(0));
    }
}
