#!/bin/bash

function verify_contract {
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    local contractAddress=$1
    local contractName=$2
    local constructorArgs=$3

    echo "Verifying $contractName: $contractAddress"
    forge verify-contract $contractAddress $contractName $constructorArgs --rpc-url $DEPLOYMENT_RPC_URL --chain $chainId --verifier-url $VERIFIER_URL --etherscan-api-key $VERIFIER_API_KEY --watch
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

    if [[ $transactionType == "CREATE" && $contractAddress != null && $contractName != null ]]; then
        verify_contract $contractAddress $contractName --guess-constructor-args
        continue
    fi

    if [[ $contractAddress == null ]]; then
        continue
    fi

    if [[ $transactionType == "CALL" ]]; then
        function=$(echo $tx | jq -r '.function')
        arguments=$(echo $tx | jq -r '.arguments')
        additionalContracts=$(echo $tx | jq -c '.additionalContracts[]')

        index=0
        for contract in $additionalContracts; do
            transactionType=$(echo $contract | jq -r '.transactionType')
            contractAddress=$(echo $contract | jq -r '.address')
            initCode=$(echo $contract | jq -r '.initCode')

            if [[ $contractName == "EulerKinkIRMFactory" || $function == "deploy(uint256,uint256,uint256,uint32)" ]]; then
                contractName=IRMLinearKink
                constructorBytesSize=128
                constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
            elif [[ $contractName == "EulerRouterFactory" || $function == "deploy(address)" ]]; then
                contractName=EulerRouter
                constructorBytesSize=64
                constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
            elif [[ $contractName == "GenericFactory" || $function == "createProxy(address,bool,bytes)" ]]; then
                if [[ $index -eq 0 ]]; then
                    upgradable=$(echo "$arguments" | jq -r '.[1]')
                    
                    if [[ $upgradable == true ]]; then
                        contractName=BeaconProxy
                        constructorBytesSize=128
                    else
                        contractName=MetaProxy
                        constructorBytesSize=160
                    fi

                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $index -eq 1 ]]; then
                    contractName=DToken
                    constructorArgs=""
                fi
            fi

            ((index++))

            if [[ $contractName == "MetaProxy" ]]; then
                continue
            fi

            verify_contract $contractAddress $contractName "$constructorArgs"

            if [[ $contractName == *Proxy* && $VERIFIER_URL == *scan.io/api* ]]; then
                curl -d "address=$contractAddress" "$VERIFIER_URL?module=contract&action=verifyproxycontract&apikey=$VERIFIER_API_KEY"
            fi
        done
    fi
done
