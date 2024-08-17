#!/bin/bash

function verify_contract {
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    local contractAddress=$1
    local contractName=$2

    echo "Verifying $contractName: $contractAddress"
    forge verify-contract $contractAddress $contractName --guess-constructor-args --rpc-url $DEPLOYMENT_RPC_URL --chain $chainId --verifier-url $VERIFIER_URL --etherscan-api-key $VERIFIER_API_KEY --watch
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
