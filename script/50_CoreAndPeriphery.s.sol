// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, Vm, console} from "./utils/ScriptUtils.s.sol";
import {ERC20BurnableMintableDeployer, RewardTokenDeployer} from "./00_ERC20.s.sol";
import {Integrations} from "./01_Integrations.s.sol";
import {PeripheryFactories} from "./02_PeripheryFactories.s.sol";
import {EVaultImplementation} from "./05_EVaultImplementation.s.sol";
import {EVaultFactory} from "./06_EVaultFactory.s.sol";
import {
    LensAccountDeployer,
    LensOracleDeployer,
    LensIRMDeployer,
    LensVaultDeployer,
    LensUtilsDeployer,
    LensEulerEarnVaultDeployer
} from "./08_Lenses.s.sol";
import {
    EVKFactoryPerspectiveDeployer,
    PerspectiveGovernedDeployer,
    EVKPerspectiveEscrowedCollateralDeployer,
    EVKPerspectiveEulerUngoverned0xDeployer,
    EVKPerspectiveEulerUngovernedNzxDeployer
} from "./09_Perspectives.s.sol";
import {Swap} from "./10_Swap.s.sol";
import {FeeFlow} from "./11_FeeFlow.s.sol";
import {
    EVaultFactoryGovernorDeployer,
    TimelockControllerDeployer,
    GovernorAccessControlEmergencyDeployer
} from "./12_Governor.s.sol";
import {TermsOfUseSignerDeployer} from "./13_TermsOfUseSigner.s.sol";
import {NttManagerDeployer, WormholeTransceiverDeployer} from "./14_NTT.s.sol";
import {FactoryGovernor} from "./../src/Governor/FactoryGovernor.sol";
import {GovernorAccessControlEmergency} from "./../src/Governor/GovernorAccessControlEmergency.sol";
import {ERC20BurnableMintable} from "./../src/ERC20/deployed/ERC20BurnableMintable.sol";
import {RewardToken} from "./../src/ERC20/deployed/RewardToken.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract CoreAndPeriphery is BatchBuilder {
    uint256 internal constant HUB_CHAIN_ID = 1;
    address internal constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint8 internal constant EUL_DECIMALS = 18;
    address internal constant EVAULT_FACTORY_GOVERNOR_PAUSER = 0xff217004BdD3A6A592162380dc0E6BbF143291eB;
    uint256 internal constant TIMELOCK_MIN_DELAY = 4 days;

    uint256 internal constant FEE_FLOW_EPOCH_PERIOD = 14 days;
    uint256 internal constant FEE_FLOW_PRICE_MULTIPLIER = 2e18;
    uint256 internal constant FEE_FLOW_MIN_INIT_PRICE = 10 ** EUL_DECIMALS;

    uint8 internal constant NTT_THRESHOLD = 1;
    bool internal constant NTT_SKIP_RATE_LIMITING = false;
    uint64 internal constant NTT_RATE_LIMIT_DURATION = 1 days;
    uint256 internal constant NTT_OUTBOUND_LIMIT = 1e5 * 10 ** EUL_DECIMALS;
    uint256 internal constant NTT_INBOUND_LIMIT = 1e4 * 10 ** EUL_DECIMALS;

    address internal constant WORMHOLE_SPECIAL_RELAYER_ADDR = address(0);
    uint8 internal constant WORMHOLE_CONSISTENCY_LEVEL = 202;
    uint256 internal constant WORMHOLE_GAS_LIMIT = 500000;

    struct Input {
        address multisigDAO;
        address multisigLabs;
        address multisigSecurityCouncil;
        address permit2;
        address uniswapV2Router;
        address uniswapV3Router;
        address wormholeCoreBridge;
        address wormholeRelayer;
        address transceiverStructs;
        uint256 feeFlowInitPrice;
    }

    function run()
        public
        returns (
            MultisigAddresses memory,
            CoreAddresses memory,
            PeripheryAddresses memory,
            LensAddresses memory,
            NTTAddresses memory
        )
    {
        string memory json = getScriptFile("50_CoreAndPeriphery_input.json");
        Input memory input = Input({
            multisigDAO: vm.parseJsonAddress(json, ".multisigDAO"),
            multisigLabs: vm.parseJsonAddress(json, ".multisigLabs"),
            multisigSecurityCouncil: vm.parseJsonAddress(json, ".multisigSecurityCouncil"),
            permit2: vm.parseJsonAddress(json, ".permit2"),
            uniswapV2Router: vm.parseJsonAddress(json, ".uniswapV2Router"),
            uniswapV3Router: vm.parseJsonAddress(json, ".uniswapV3Router"),
            wormholeCoreBridge: vm.parseJsonAddress(json, ".wormholeCoreBridge"),
            wormholeRelayer: vm.parseJsonAddress(json, ".wormholeRelayer"),
            transceiverStructs: vm.parseJsonAddress(json, ".transceiverStructs"),
            feeFlowInitPrice: vm.parseJsonUint(json, ".feeFlowInitPrice")
        });

        if (
            !isBroadcast() && nttAddresses.manager == address(0) && nttAddresses.transceiver == address(0)
                && input.wormholeCoreBridge != address(0) && input.wormholeRelayer != address(0)
        ) {
            startBroadcast();
            bytes memory bytecode = vm.getCode("out-ntt/TransceiverStructs.sol/TransceiverStructs.json");
            address lib;
            assembly {
                lib := create(0, add(bytecode, 0x20), mload(bytecode))
            }
            stopBroadcast();
            require(input.transceiverStructs == lib, "TransceiverStructs address mismatch");
        }

        if (
            multisigAddresses.DAO == address(0) && multisigAddresses.labs == address(0)
                && multisigAddresses.securityCouncil == address(0)
        ) {
            console.log("+ Assigning multisig addresses...");
            multisigAddresses.DAO = input.multisigDAO;
            multisigAddresses.labs = input.multisigLabs;
            multisigAddresses.securityCouncil = input.multisigSecurityCouncil;
        } else {
            console.log("- At least one of the multisig addresses already assigned. Skipping...");
        }

        verifyMultisigAddresses(multisigAddresses);

        if (
            coreAddresses.evc == address(0) && coreAddresses.protocolConfig == address(0)
                && coreAddresses.sequenceRegistry == address(0) && coreAddresses.balanceTracker == address(0)
                && coreAddresses.permit2 == address(0)
        ) {
            console.log("+ Deploying Integrations...");
            Integrations deployer = new Integrations();
            (
                coreAddresses.evc,
                coreAddresses.protocolConfig,
                coreAddresses.sequenceRegistry,
                coreAddresses.balanceTracker,
                coreAddresses.permit2
            ) = deployer.deploy(input.permit2);
        } else {
            console.log("- At least one of the Integrations contracts already deployed. Skipping...");
        }

        if (coreAddresses.eVaultImplementation == address(0)) {
            console.log("+ Deploying EVault implementation...");
            EVaultImplementation deployer = new EVaultImplementation();
            Base.Integrations memory integrations = Base.Integrations({
                evc: coreAddresses.evc,
                protocolConfig: coreAddresses.protocolConfig,
                sequenceRegistry: coreAddresses.sequenceRegistry,
                balanceTracker: coreAddresses.balanceTracker,
                permit2: coreAddresses.permit2
            });
            (, coreAddresses.eVaultImplementation) = deployer.deploy(integrations);
        } else {
            console.log("- EVault implementation already deployed. Skipping...");
        }

        if (coreAddresses.eVaultFactory == address(0)) {
            console.log("+ Deploying EVault factory...");
            EVaultFactory deployer = new EVaultFactory();
            coreAddresses.eVaultFactory = deployer.deploy(coreAddresses.eVaultImplementation);
        } else {
            console.log("- EVault factory already deployed. Skipping...");
        }

        if (governorAddresses.eVaultFactoryGovernor == address(0)) {
            console.log("+ Deploying EVault factory governor...");
            EVaultFactoryGovernorDeployer deployer = new EVaultFactoryGovernorDeployer();
            governorAddresses.eVaultFactoryGovernor = deployer.deploy();

            bytes32 pauseGuardianRole = FactoryGovernor(governorAddresses.eVaultFactoryGovernor).PAUSE_GUARDIAN_ROLE();
            bytes32 unpauseAdminRole = FactoryGovernor(governorAddresses.eVaultFactoryGovernor).UNPAUSE_ADMIN_ROLE();

            startBroadcast();
            console.log("    Granting pause guardian role to address %s", multisigAddresses.labs);
            AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(pauseGuardianRole, multisigAddresses.labs);

            console.log("    Granting pause guardian role to address %s", EVAULT_FACTORY_GOVERNOR_PAUSER);
            AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(
                pauseGuardianRole, EVAULT_FACTORY_GOVERNOR_PAUSER
            );

            console.log("    Granting unpause admin role to address %s", multisigAddresses.labs);
            AccessControl(governorAddresses.eVaultFactoryGovernor).grantRole(unpauseAdminRole, multisigAddresses.labs);
            stopBroadcast();
        } else {
            console.log("- EVault factory governor already deployed. Skipping...");
        }

        if (governorAddresses.eVaultFactoryTimelockController == address(0)) {
            console.log("+ Deploying EVault factory timelock controller...");
            TimelockControllerDeployer deployer = new TimelockControllerDeployer();
            address[] memory proposers = new address[](1);
            address[] memory executors = new address[](1);
            proposers[0] = multisigAddresses.DAO;
            executors[0] = address(0);
            governorAddresses.eVaultFactoryTimelockController =
                deployer.deploy(TIMELOCK_MIN_DELAY, proposers, executors);

            console.log("    Granting proposer role to address %s", multisigAddresses.DAO);
            console.log("    Granting canceller role to address %s", multisigAddresses.DAO);
            console.log("    Granting executor role to anyone");
            console.log("    Granting canceller role to address %s", multisigAddresses.securityCouncil);

            startBroadcast();
            bytes32 cancellerRole =
                TimelockController(payable(governorAddresses.eVaultFactoryTimelockController)).CANCELLER_ROLE();
            AccessControl(governorAddresses.eVaultFactoryTimelockController).grantRole(
                cancellerRole, multisigAddresses.securityCouncil
            );
            stopBroadcast();
        } else {
            console.log("- EVault factory timelock controller already deployed. Skipping...");
        }

        if (governorAddresses.accessControlEmergencyGovernor == address(0)) {
            console.log("+ Deploying Emergency Access Control Governor...");
            GovernorAccessControlEmergencyDeployer deployer = new GovernorAccessControlEmergencyDeployer();
            governorAddresses.accessControlEmergencyGovernor = deployer.deploy(coreAddresses.evc);

            bytes32 wildCardRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).WILD_CARD();
            bytes32 ltvEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).LTV_EMERGENCY_ROLE();
            bytes32 hookEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).HOOK_EMERGENCY_ROLE();
            bytes32 capsEmergencyRole =
                GovernorAccessControlEmergency(governorAddresses.accessControlEmergencyGovernor).CAPS_EMERGENCY_ROLE();

            console.log("    Granting wild card role to address %s", multisigAddresses.DAO);
            grantRole(governorAddresses.accessControlEmergencyGovernor, wildCardRole, multisigAddresses.DAO);

            console.log("    Granting LTV emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, ltvEmergencyRole, multisigAddresses.labs);

            console.log("    Granting hook emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, hookEmergencyRole, multisigAddresses.labs);

            console.log("    Granting caps emergency role to address %s", multisigAddresses.labs);
            grantRole(governorAddresses.accessControlEmergencyGovernor, capsEmergencyRole, multisigAddresses.labs);
        } else {
            console.log("- Vault Access Control Emergency Governor already deployed. Skipping...");
        }

        if (tokenAddresses.EUL == address(0) && block.chainid != HUB_CHAIN_ID) {
            console.log("+ Deploying EUL...");
            ERC20BurnableMintableDeployer deployer = new ERC20BurnableMintableDeployer();
            tokenAddresses.EUL = deployer.deploy("Euler", "EUL", EUL_DECIMALS);

            startBroadcast();
            console.log("    Granting EUL revoke minter role to the desired address %s", multisigAddresses.labs);
            bytes32 revokeMinterRole = ERC20BurnableMintable(tokenAddresses.EUL).REVOKE_MINTER_ROLE();
            AccessControl(tokenAddresses.EUL).grantRole(revokeMinterRole, multisigAddresses.labs);
            stopBroadcast();
        } else {
            console.log("- EUL already deployed. Skipping...");
        }

        if (tokenAddresses.rEUL == address(0)) {
            console.log("+ Deploying rEUL...");
            RewardTokenDeployer deployer = new RewardTokenDeployer();
            tokenAddresses.rEUL =
                deployer.deploy(coreAddresses.evc, BURN_ADDRESS, tokenAddresses.EUL, "Reward EUL", "rEUL");

            console.log("    Setting whitelist admin status for address %s", multisigAddresses.labs);
            uint256 whitelistStatusAdmin = RewardToken(tokenAddresses.rEUL).WHITELIST_STATUS_ADMIN();
            setWhitelistStatus(tokenAddresses.rEUL, multisigAddresses.labs, whitelistStatusAdmin);
        } else {
            console.log("- rEUL already deployed. Skipping...");
        }

        if (nttAddresses.manager == address(0) && nttAddresses.transceiver == address(0)) {
            if (input.wormholeCoreBridge != address(0) && input.wormholeRelayer != address(0)) {
                console.log("+ Deploying NttManager and WormholeTransceiver...");
                uint16 wormholeChainId = NttManager(input.wormholeCoreBridge).chainId();
                {
                    NttManagerDeployer deployer = new NttManagerDeployer();
                    nttAddresses.manager = deployer.deploy(
                        tokenAddresses.EUL,
                        block.chainid == HUB_CHAIN_ID ? true : false,
                        wormholeChainId,
                        NTT_RATE_LIMIT_DURATION,
                        NTT_SKIP_RATE_LIMITING
                    );
                }
                {
                    WormholeTransceiverDeployer deployer = new WormholeTransceiverDeployer();
                    nttAddresses.transceiver = deployer.deploy(
                        nttAddresses.manager,
                        input.wormholeCoreBridge,
                        input.wormholeRelayer,
                        WORMHOLE_SPECIAL_RELAYER_ADDR,
                        WORMHOLE_CONSISTENCY_LEVEL,
                        WORMHOLE_GAS_LIMIT
                    );
                }

                startBroadcast();
                console.log("    Setting NttManager (%s) transceiver", block.chainid);
                NttManager(nttAddresses.manager).setTransceiver(nttAddresses.transceiver);

                console.log("    Setting NttManager (%s) outbound limit", block.chainid);
                NttManager(nttAddresses.manager).setOutboundLimit(NTT_OUTBOUND_LIMIT);

                console.log("    Setting NttManager (%s) threshold", block.chainid);
                NttManager(nttAddresses.manager).setThreshold(NTT_THRESHOLD);

                console.log(
                    "    Transferring NttManager (%s) pauser capability to %s", block.chainid, multisigAddresses.labs
                );
                NttManager(nttAddresses.manager).transferPauserCapability(multisigAddresses.labs);

                console.log(
                    "    Transferring WormholeTransceiver (%s) pauser capability to %s",
                    block.chainid,
                    multisigAddresses.labs
                );
                WormholeTransceiver(nttAddresses.transceiver).transferPauserCapability(multisigAddresses.labs);
                stopBroadcast();

                if (block.chainid != HUB_CHAIN_ID) {
                    NTTAddresses memory nttAddressesHub =
                        deserializeNTTAddresses(getAddressesJson("NTTAddresses.json", HUB_CHAIN_ID));

                    selectFork(HUB_CHAIN_ID);
                    verifyNTTAddresses(nttAddressesHub);
                    uint16 wormholeChainIdHub = NttManager(nttAddressesHub.manager).chainId();
                    selectFork(DEFAULT_FORK_CHAIN_ID);

                    startBroadcast();
                    console.log(
                        "    Setting NttManager (%s) peer to %s for chain %s",
                        block.chainid,
                        nttAddressesHub.manager,
                        HUB_CHAIN_ID
                    );
                    NttManager(nttAddresses.manager).setPeer(
                        wormholeChainIdHub,
                        bytes32(uint256(uint160(nttAddressesHub.manager))),
                        EUL_DECIMALS,
                        NTT_INBOUND_LIMIT
                    );

                    console.log(
                        "    Setting WormholeTransceiver (%s) peer to %s for chain %s",
                        block.chainid,
                        nttAddressesHub.transceiver,
                        HUB_CHAIN_ID
                    );
                    WormholeTransceiver(nttAddresses.transceiver).setWormholePeer(
                        wormholeChainIdHub, bytes32(uint256(uint160(nttAddressesHub.transceiver)))
                    );

                    console.log(
                        "    Setting WormholeTransceiver (%s) isWormholeEvmChain for chain %s",
                        block.chainid,
                        HUB_CHAIN_ID
                    );
                    WormholeTransceiver(nttAddresses.transceiver).setIsWormholeEvmChain(wormholeChainIdHub, true);

                    console.log(
                        "    Setting WormholeTransceiver (%s) isWormholeRelayingEnabled for chain %s",
                        block.chainid,
                        HUB_CHAIN_ID
                    );
                    WormholeTransceiver(nttAddresses.transceiver).setIsWormholeRelayingEnabled(wormholeChainIdHub, true);

                    bytes32 defaultAdminRole = ERC20BurnableMintable(tokenAddresses.EUL).DEFAULT_ADMIN_ROLE();
                    if (ERC20BurnableMintable(tokenAddresses.EUL).hasRole(defaultAdminRole, getDeployer())) {
                        console.log("    Granting EUL minter role to the NttManager address %s", nttAddresses.manager);
                        bytes32 minterRole = ERC20BurnableMintable(tokenAddresses.EUL).MINTER_ROLE();
                        AccessControl(tokenAddresses.EUL).grantRole(minterRole, nttAddresses.manager);
                    } else {
                        console.log(
                            "    ! The deployer no longer has the EUL default admin role to grant the minter role to the NttManager. This must be done manually. Skipping..."
                        );
                    }
                    stopBroadcast();
                }
            } else {
                console.log(
                    "! WormholeCoreBridge or WormholeRelayer not set for NttManager and WormholeTransceiver deployment. Skipping..."
                );
            }
        } else {
            console.log("- NttManager or WormholeTransceiver already deployed. Skipping...");
        }

        if (
            block.chainid == HUB_CHAIN_ID && nttAddresses.manager != address(0)
                && nttAddresses.transceiver != address(0)
        ) {
            console.log("+ Attempting to configure NttManager and WormholeTransceiver (%s)...", block.chainid);
            bool isManagerOwner = NttManager(nttAddresses.manager).owner() == getDeployer();
            bool isTransceiverOwner = NttManager(nttAddresses.transceiver).owner() == getDeployer();

            if (!isManagerOwner) {
                console.log(
                    "    ! The caller of this script is not the NttManager owner. Below NttManager configuration must be done manually."
                );
            }

            if (!isTransceiverOwner) {
                console.log(
                    "    ! The caller of this script is not the WormholeTransceiver owner. Below WormholeTransceiver configuration must be done manually."
                );
            }

            string memory addressesDirPath = getAddressesDirPath();
            Vm.DirEntry[] memory entries = vm.readDir(addressesDirPath, 1);

            for (uint256 i = 0; i < entries.length; ++i) {
                if (!entries[i].isDir) continue;

                uint256 chainIdOther = getChainIdFromAddressessDirPath(entries[i].path);

                if (chainIdOther == 0 || chainIdOther == HUB_CHAIN_ID) continue;

                NTTAddresses memory nttAddressesOther =
                    deserializeNTTAddresses(getAddressesJson("NTTAddresses.json", chainIdOther));

                if (nttAddressesOther.manager == address(0) || nttAddressesOther.transceiver == address(0)) {
                    console.log(
                        "    ! NttManager or WormholeTransceiver not deployed for chain %s. Skipping...", chainIdOther
                    );
                    continue;
                }

                selectFork(chainIdOther);
                verifyNTTAddresses(nttAddressesOther);
                uint16 wormholeChainIdOther = NttManager(nttAddressesOther.manager).chainId();
                selectFork(DEFAULT_FORK_CHAIN_ID);

                startBroadcast();
                console.log(
                    "    Attempting to configure NttManager and WormholeTransceiver (%s) for chain %s:",
                    block.chainid,
                    chainIdOther
                );
                if (
                    NttManager(nttAddresses.manager).getPeer(wormholeChainIdOther).peerAddress
                        != bytes32(uint256(uint160(nttAddressesOther.manager)))
                ) {
                    console.log(
                        "        Setting NttManager (%s) peer to %s for chain %s",
                        block.chainid,
                        nttAddressesOther.manager,
                        chainIdOther
                    );
                    if (isManagerOwner) {
                        NttManager(nttAddresses.manager).setPeer(
                            wormholeChainIdOther,
                            bytes32(uint256(uint160(nttAddressesOther.manager))),
                            EUL_DECIMALS,
                            NTT_INBOUND_LIMIT
                        );
                    }
                }

                if (
                    WormholeTransceiver(nttAddresses.transceiver).getWormholePeer(wormholeChainIdOther)
                        != bytes32(uint256(uint160(nttAddressesOther.transceiver)))
                ) {
                    console.log(
                        "        Setting WormholeTransceiver (%s) peer to %s for chain %s",
                        block.chainid,
                        nttAddressesOther.transceiver,
                        chainIdOther
                    );
                    if (isTransceiverOwner) {
                        WormholeTransceiver(nttAddresses.transceiver).setWormholePeer(
                            wormholeChainIdOther, bytes32(uint256(uint160(nttAddressesOther.transceiver)))
                        );
                    }
                }

                if (!WormholeTransceiver(nttAddresses.transceiver).isWormholeEvmChain(wormholeChainIdOther)) {
                    console.log(
                        "        Setting WormholeTransceiver (%s) isWormholeEvmChain for chain %s",
                        block.chainid,
                        chainIdOther
                    );
                    if (isTransceiverOwner) {
                        WormholeTransceiver(nttAddresses.transceiver).setIsWormholeEvmChain(wormholeChainIdOther, true);
                    }
                }

                if (!WormholeTransceiver(nttAddresses.transceiver).isWormholeRelayingEnabled(wormholeChainIdOther)) {
                    console.log(
                        "        Setting WormholeTransceiver (%s) isWormholeRelayingEnabled for chain %s",
                        block.chainid,
                        chainIdOther
                    );
                    if (isTransceiverOwner) {
                        WormholeTransceiver(nttAddresses.transceiver).setIsWormholeRelayingEnabled(
                            wormholeChainIdOther, true
                        );
                    }
                }
                stopBroadcast();
            }
        }

        if (
            peripheryAddresses.oracleRouterFactory == address(0)
                && peripheryAddresses.oracleAdapterRegistry == address(0)
                && peripheryAddresses.externalVaultRegistry == address(0) && peripheryAddresses.kinkIRMFactory == address(0)
                && peripheryAddresses.irmRegistry == address(0)
        ) {
            console.log("+ Deploying Periphery factories...");
            PeripheryFactories deployer = new PeripheryFactories();
            (
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry
            ) = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("- At least one of the Periphery factories contracts already deployed. Skipping...");
        }

        if (peripheryAddresses.feeFlowController == address(0)) {
            if (input.feeFlowInitPrice != 0) {
                console.log("+ Deploying FeeFlow...");
                FeeFlow deployer = new FeeFlow();
                peripheryAddresses.feeFlowController = deployer.deploy(
                    coreAddresses.evc,
                    input.feeFlowInitPrice,
                    tokenAddresses.EUL,
                    BURN_ADDRESS,
                    FEE_FLOW_EPOCH_PERIOD,
                    FEE_FLOW_PRICE_MULTIPLIER,
                    FEE_FLOW_MIN_INIT_PRICE
                );

                if (ProtocolConfig(coreAddresses.protocolConfig).admin() == getDeployer()) {
                    startBroadcast();
                    console.log(
                        "    Setting ProtocolConfig fee receiver to the FeeFlowController address %s",
                        peripheryAddresses.feeFlowController
                    );
                    ProtocolConfig(coreAddresses.protocolConfig).setFeeReceiver(peripheryAddresses.feeFlowController);
                    stopBroadcast();
                } else {
                    console.log(
                        "    ! The deployer no longer has the ProtocolConfig admin role to set the FeeFlowController address. This must be done manually. Skipping..."
                    );
                }
            } else {
                console.log("! feeFlowInitPrice is not set for FeeFlow deployment. Skipping...");
            }
        } else {
            console.log("- FeeFlowController already deployed. Skipping...");
        }

        if (peripheryAddresses.swapper == address(0) && peripheryAddresses.swapVerifier == address(0)) {
            console.log("+ Deploying Swapper...");
            Swap deployer = new Swap();
            (peripheryAddresses.swapper, peripheryAddresses.swapVerifier) =
                deployer.deploy(input.uniswapV2Router, input.uniswapV3Router);
        } else {
            console.log("- At least one of the Swapper contracts already deployed. Skipping...");
        }

        if (peripheryAddresses.evkFactoryPerspective == address(0)) {
            console.log("+ Deploying EVKFactoryPerspective...");
            EVKFactoryPerspectiveDeployer deployer = new EVKFactoryPerspectiveDeployer();
            peripheryAddresses.evkFactoryPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("- EVKFactoryPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.governedPerspective == address(0)) {
            console.log("+ Deploying GovernedPerspective...");
            PerspectiveGovernedDeployer deployer = new PerspectiveGovernedDeployer();
            peripheryAddresses.governedPerspective = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("- GovernedPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.escrowedCollateralPerspective == address(0)) {
            console.log("+ Deploying EscrowedCollateralPerspective...");
            EVKPerspectiveEscrowedCollateralDeployer deployer = new EVKPerspectiveEscrowedCollateralDeployer();
            peripheryAddresses.escrowedCollateralPerspective = deployer.deploy(coreAddresses.eVaultFactory);
        } else {
            console.log("- EscrowedCollateralPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngoverned0xPerspective == address(0)) {
            console.log("+ Deploying EulerUngoverned0xPerspective...");
            EVKPerspectiveEulerUngoverned0xDeployer deployer = new EVKPerspectiveEulerUngoverned0xDeployer();
            peripheryAddresses.eulerUngoverned0xPerspective = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry,
                peripheryAddresses.escrowedCollateralPerspective
            );
        } else {
            console.log("- EulerUngoverned0xPerspective already deployed. Skipping...");
        }
        if (peripheryAddresses.eulerUngovernedNzxPerspective == address(0)) {
            console.log("+ Deploying EulerUngovernedNzxPerspective...");
            EVKPerspectiveEulerUngovernedNzxDeployer deployer = new EVKPerspectiveEulerUngovernedNzxDeployer();
            peripheryAddresses.eulerUngovernedNzxPerspective = deployer.deploy(
                coreAddresses.eVaultFactory,
                peripheryAddresses.oracleRouterFactory,
                peripheryAddresses.oracleAdapterRegistry,
                peripheryAddresses.externalVaultRegistry,
                peripheryAddresses.kinkIRMFactory,
                peripheryAddresses.irmRegistry,
                peripheryAddresses.governedPerspective,
                peripheryAddresses.escrowedCollateralPerspective
            );
        } else {
            console.log("- EulerUngovernedNzxPerspective already deployed. Skipping...");
        }

        if (peripheryAddresses.termsOfUseSigner == address(0)) {
            console.log("+ Deploying Terms of use signer...");
            TermsOfUseSignerDeployer deployer = new TermsOfUseSignerDeployer();
            peripheryAddresses.termsOfUseSigner = deployer.deploy(coreAddresses.evc);
        } else {
            console.log("- Terms of use signer already deployed. Skipping...");
        }

        if (lensAddresses.accountLens == address(0)) {
            console.log("+ Deploying LensAccount...");
            LensAccountDeployer deployer = new LensAccountDeployer();
            lensAddresses.accountLens = deployer.deploy();
        } else {
            console.log("- LensAccount already deployed. Skipping...");
        }
        if (lensAddresses.oracleLens == address(0)) {
            console.log("+ Deploying LensOracle...");
            LensOracleDeployer deployer = new LensOracleDeployer();
            lensAddresses.oracleLens = deployer.deploy(peripheryAddresses.oracleAdapterRegistry);
        } else {
            console.log("- LensOracle already deployed. Skipping...");
        }
        if (lensAddresses.irmLens == address(0)) {
            console.log("+ Deploying LensIRM...");
            LensIRMDeployer deployer = new LensIRMDeployer();
            lensAddresses.irmLens = deployer.deploy(peripheryAddresses.kinkIRMFactory);
        } else {
            console.log("- LensIRM already deployed. Skipping...");
        }
        if (lensAddresses.utilsLens == address(0)) {
            console.log("+ Deploying LensUtils...");
            LensUtilsDeployer deployer = new LensUtilsDeployer();
            lensAddresses.utilsLens = deployer.deploy(lensAddresses.oracleLens);
        } else {
            console.log("- LensUtils already deployed. Skipping...");
        }
        if (lensAddresses.vaultLens == address(0)) {
            console.log("+ Deploying LensVault...");
            LensVaultDeployer deployer = new LensVaultDeployer();
            lensAddresses.vaultLens =
                deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens, lensAddresses.irmLens);
        } else {
            console.log("- LensVault already deployed. Skipping...");
        }
        //if (lensAddresses.eulerEarnVaultLens == address(0)) {
        //    console.log("+ Deploying EulerEarnVaultLens...");
        //    LensEulerEarnVaultDeployer deployer = new LensEulerEarnVaultDeployer();
        //    lensAddresses.eulerEarnVaultLens = deployer.deploy(lensAddresses.oracleLens, lensAddresses.utilsLens);
        //} else {
        //    console.log("- EulerEarnVaultLens already deployed. Skipping...");
        //}

        executeBatch();

        // save results
        vm.writeJson(serializeMultisigAddresses(multisigAddresses), getScriptFilePath("MultisigAddresses_output.json"));
        vm.writeJson(serializeCoreAddresses(coreAddresses), getScriptFilePath("CoreAddresses_output.json"));
        vm.writeJson(
            serializePeripheryAddresses(peripheryAddresses), getScriptFilePath("PeripheryAddresses_output.json")
        );
        vm.writeJson(serializeGovernorAddresses(governorAddresses), getScriptFilePath("GovernorAddresses_output.json"));
        vm.writeJson(serializeTokenAddresses(tokenAddresses), getScriptFilePath("TokenAddresses_output.json"));
        vm.writeJson(serializeLensAddresses(lensAddresses), getScriptFilePath("LensAddresses_output.json"));
        vm.writeJson(serializeNTTAddresses(nttAddresses), getScriptFilePath("NTTAddresses_output.json"));

        if (isBroadcast() && !isLocalForkDeployment()) {
            vm.createDir(getAddressesFilePath("", block.chainid), true);

            vm.writeJson(
                serializeMultisigAddresses(multisigAddresses),
                getAddressesFilePath("MultisigAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeCoreAddresses(coreAddresses), getAddressesFilePath("CoreAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializePeripheryAddresses(peripheryAddresses),
                getAddressesFilePath("PeripheryAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeGovernorAddresses(governorAddresses),
                getAddressesFilePath("GovernorAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeTokenAddresses(tokenAddresses), getAddressesFilePath("TokenAddresses.json", block.chainid)
            );
            vm.writeJson(
                serializeLensAddresses(lensAddresses), getAddressesFilePath("LensAddresses.json", block.chainid)
            );
            vm.writeJson(serializeNTTAddresses(nttAddresses), getAddressesFilePath("NTTAddresses.json", block.chainid));
        }

        return (multisigAddresses, coreAddresses, peripheryAddresses, lensAddresses, nttAddresses);
    }
}
