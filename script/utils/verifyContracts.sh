#!/bin/bash

function verify_contract {
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    local contractAddress=$1
    local contractName=$2
    local chain=$(get_chain_from_id $chainId)
    local verify_command="forge verify-contract $contractAddress $contractName --rpc-url $DEPLOYMENT_RPC_URL --chain $chain --verifier-url $VERIFIER_URL --etherscan-api-key $VERIFIER_API_KEY --skip-is-verified-check --watch"
    
    echo "Verifying $contractName: $contractAddress"
    result=$(eval $verify_command --flatten --force 2>&1)

    if [[ "$result" != *"Contract successfully verified"* ]]; then
        result=$(eval $verify_command 2>&1)
        if [[ "$result" != *"Contract successfully verified"* ]]; then
            echo "Failure"
        fi
    fi
}

function get_chain_from_id {
    local chainId=$1
    
    case $chainId in
        1) echo "mainnet" ;;
        2) echo "morden" ;;
        3) echo "ropsten" ;;
        4) echo "rinkeby" ;;
        5) echo "goerli" ;;
        42) echo "kovan" ;;
        17000) echo "holesky" ;;
        11155111) echo "sepolia" ;;
        10) echo "optimism" ;;
        69) echo "optimism-kovan" ;;
        420) echo "optimism-goerli" ;;
        11155420) echo "optimism-sepolia" ;;
        42161) echo "arbitrum" ;;
        421611) echo "arbitrum-testnet" ;;
        421613) echo "arbitrum-goerli" ;;
        421614) echo "arbitrum-sepolia" ;;
        42170) echo "arbitrum-nova" ;;
        25) echo "cronos" ;;
        338) echo "cronos-testnet" ;;
        30) echo "rsk" ;;
        56) echo "bsc" ;;
        97) echo "bsc-testnet" ;;
        99) echo "poa" ;;
        77) echo "sokol" ;;
        534352) echo "scroll" ;;
        534351) echo "scroll-sepolia" ;;
        1088) echo "metis" ;;
        100) echo "xdai" ;;
        137) echo "polygon" ;;
        80001) echo "mumbai" ;;
        80002) echo "amoy" ;;
        1101) echo "polygon-zkevm" ;;
        1442) echo "polygon-zkevm-testnet" ;;
        250) echo "fantom" ;;
        4002) echo "fantom-testnet" ;;
        1284) echo "moonbeam" ;;
        1281) echo "moonbeam-dev" ;;
        1285) echo "moonriver" ;;
        1287) echo "moonbase" ;;
        2018) echo "dev" ;;
        31337) echo "anvil-hardhat" ;;
        9001) echo "evmos" ;;
        9000) echo "evmos-testnet" ;;
        10200) echo "chiado" ;;
        42262) echo "oasis" ;;
        42261) echo "emerald" ;;
        42262) echo "emerald-testnet" ;;
        314) echo "filecoin-mainnet" ;;
        314159) echo "filecoin-calibration-testnet" ;;
        43114) echo "avalanche" ;;
        43113) echo "fuji" ;;
        42220) echo "celo" ;;
        44787) echo "celo-alfajores" ;;
        62320) echo "celo-baklava" ;;
        1313161554) echo "aurora" ;;
        1313161555) echo "aurora-testnet" ;;
        7700) echo "canto" ;;
        7701) echo "canto-testnet" ;;
        288) echo "boba" ;;
        8453) echo "base" ;;
        84531) echo "base-goerli" ;;
        84532) echo "base-sepolia" ;;
        204) echo "syndr" ;;
        11155111) echo "syndr-sepolia" ;;
        1071) echo "shimmer" ;;
        252) echo "fraxtal" ;;
        2522) echo "fraxtal-testnet" ;;
        81457) echo "blast" ;;
        168587773) echo "blast-sepolia" ;;
        59144) echo "linea" ;;
        59140) echo "linea-goerli" ;;
        324) echo "zksync" ;;
        280) echo "zksync-testnet" ;;
        5000) echo "mantle" ;;
        5001) echo "mantle-testnet" ;;
        5003) echo "mantle-sepolia" ;;
        88) echo "viction" ;;
        7777777) echo "zora" ;;
        999) echo "zora-goerli" ;;
        999999999) echo "zora-sepolia" ;;
        424) echo "pgn" ;;
        58008) echo "pgn-sepolia" ;;
        34443) echo "mode" ;;
        919) echo "mode-sepolia" ;;
        20) echo "elastos" ;;
        12008) echo "kakarot-sepolia" ;;
        128123) echo "etherlink-testnet" ;;
        69420) echo "degen" ;;
        204) echo "opbnb-mainnet" ;;
        5611) echo "opbnb-testnet" ;;
        2020) echo "ronin" ;;
        167004) echo "taiko" ;;
        167005) echo "taiko-hekla" ;;
        1392) echo "autonomys-nova-testnet" ;;
        14) echo "flare" ;;
        114) echo "flare-coston2" ;;
        *) echo "unknown" ;;
    esac
}

source .env

# Verify the deployed smart contracts
fileName=$1
tmpFileName=${fileName}.tmp
sed 's/, /,/g' $fileName > $tmpFileName

# Iterate over each transaction and verify it
transactions=$(jq -c '.transactions[]' $tmpFileName)
rm $tmpFileName

for tx in $transactions; do
    transactionType=$(echo $tx | jq -r '.transactionType')
    contractAddress=$(echo $tx | jq -r '.contractAddress')
    contractName=$(echo $tx | jq -r '.contractName')

    if [[ $contractName == null || $contractAddress == null ]]; then
        continue
    fi

    if [[ $transactionType == "CREATE" ]]; then
        verify_contract $contractAddress $contractName
        continue
    fi

    if [[ $transactionType == "CALL" ]]; then
        additionalContracts=$(echo $tx | jq -c '.additionalContracts[]')

        index=0
        for contract in $additionalContracts; do
            transactionType=$(echo $contract | jq -r '.transactionType')
            contractAddress=$(echo $contract | jq -r '.address')

            if [[ $contractName == "EulerKinkIRMFactory" ]]; then
                verify_contract $contractAddress IRMLinearKink
            elif [[ $contractName == "EulerRouterFactory" ]]; then
                verify_contract $contractAddress EulerRouter
            elif [[ $contractName == "GenericFactory" ]]; then
                if [[ $index -eq 0 ]]; then
                    #verify_contract $contractAddress BeaconProxy
                    true
                elif [[ $index -eq 1 ]]; then
                    verify_contract $contractAddress DToken
                fi
            fi
            
            ((index++))
        done
    fi
done
