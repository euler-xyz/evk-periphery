#!/bin/bash

function verify_contract {
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    local contractAddress=$1
    local contractName=$2
    local constructorArgs=$3
    shift 4
    
    local verifier_url_var="VERIFIER_URL_${chainId}"
    local verifier_api_key_var="VERIFIER_API_KEY_${chainId}"
    local verifier_url=${VERIFIER_URL:-${!verifier_url_var}}
    local verifier_api_key=""
    local verifier=""

    if [[ "$@" == *"--verifier"* ]]; then
        verifier=$(echo "$@" | grep -o '\--verifier [^ ]*' | cut -d ' ' -f 2)
        set -- $(echo "$@" | sed "s/--verifier $verifier//")
    else
        verifier="etherscan"
    fi

    if [[ $VERIFIER_URL == "" ]]; then
        verifier_api_key=${!verifier_api_key_var}
    else
        verifier_api_key=$VERIFIER_API_KEY
    fi

    local verifierArgs="--verifier-url $verifier_url"

    if [[ $verifier == "blockscout" ]]; then
        verifierArgs="$verifierArgs --verifier-api-key \"\" --verifier=blockscout"

        if [[ $constructorArgs == "--guess-constructor-args" ]]; then
            constructorArgs=""
        fi
    elif [[ $verifier == "custom" ]]; then
        verifierArgs="$verifierArgs --verifier=$verifier"
    else
        verifierArgs="$verifierArgs --verifier-api-key $verifier_api_key --verifier=$verifier"
    fi

    echo "Verifying $contractName: $contractAddress"
    env VERIFIER_API_KEY=$verifier_api_key ETHERSCAN_API_KEY=$verifier_api_key \
        forge verify-contract $contractAddress $contractName $constructorArgs --rpc-url $DEPLOYMENT_RPC_URL --chain $chainId $verifierArgs --watch $@ #--show-standard-json-input > $contractAddress.json
    result=$?

    if [[ $result -eq 0 && $contractName == *Proxy* && $verifier_url == *scan.io/api* ]]; then
        curl -d "address=$contractAddress" "$verifier_url?module=contract&action=verifyproxycontract&apikey=$verifier_api_key"
    fi

    return $result
}

function verify_broadcast {
    local fileName=$1
    local tmpFileName=${fileName}.tmp
    sed 's/, /,/g; s/\\"//g; s/ //g' $fileName > $tmpFileName
    local transactions=$(jq -c '.transactions[]' $tmpFileName)
    rm $tmpFileName

    if [ $(echo "$transactions" | wc -l) -lt 5 ]; then
        sleep 10
    fi

    local createVerified=false
    local eulerEarnIndex=0
    for tx in $transactions; do
        local transactionType=$(echo $tx | jq -r '.transactionType')
        local contractAddress=$(echo $tx | jq -r '.contractAddress')
        local contractName=$(echo $tx | jq -r '.contractName')
        local additionalContracts=$(echo $tx | jq -c '.additionalContracts[]')
        local initCode=$(echo $tx | jq -r '.transaction.input')
        local verificationSuccessful=false

        if [[ $transactionType == "CREATE" && $contractAddress != null && $contractName != null ]]; then
            if [ "$createVerified" = true ]; then
                createVerified=false
                forge clean && forge compile
            fi

            constructorArgs="--guess-constructor-args"

            if [[ $contractName == "ERC1967Proxy" ]]; then
                constructorBytesSize=64
                constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
            elif [[ $contractName == "TransparentUpgradeableProxy" ]]; then
                constructorArgs="--constructor-args $(echo $initCode | sed 's/.*8180033//' | cut -c65-)"
            elif [[ $contractName == "OFTAdapterUpgradeable" ]]; then
                contractName="./src/OFT/OFTAdapterUpgradeable.sol:OFTAdapterUpgradeable"
                constructorBytesSize=64
                constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
            fi

            verify_contract $contractAddress $contractName "$constructorArgs" "$@"

            if [ $? -eq 0 ]; then
                verificationSuccessful=true
            fi
        fi

        if [[ $contractAddress == null ]]; then
            continue
        fi

        if [[ $transactionType == "CALL" || ($transactionType == "CREATE" && $additionalContracts != "") ]]; then
            if [ "$createVerified" = true ]; then
                createVerified=false
                forge clean && forge compile
            fi

            local function=$(echo $tx | jq -r '.function')
            local arguments=$(echo $tx | jq -r '.arguments')

            index=0
            for contract in $additionalContracts; do
                local transactionType=$(echo $contract | jq -r '.transactionType')
                local contractAddress=$(echo $contract | jq -r '.address')
                local initCode=$(echo $contract | jq -r '.initCode')

                if [[ $contractName == "EulerKinkIRMFactory" || $function == "deploy(uint256,uint256,uint256,uint32)" ]]; then
                    contractName=IRMLinearKink
                    constructorBytesSize=128
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "EulerIRMAdaptiveCurveFactory" || $function == "deploy(int256,int256,int256,int256,int256,int256)" ]]; then
                    contractName=IRMAdaptiveCurve
                    constructorBytesSize=192
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "EulerRouterFactory" || $function == "deploy(address)" ]]; then
                    contractName=EulerRouter
                    constructorBytesSize=32
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "GovernorAccessControlEmergencyFactory" || $function == "deploy((uint256,address[],address[],address[]),(uint256,address[],address[],address[]),address[])" ]]; then
                    if [[ $index -eq 0 ]]; then
                        contractName=TimelockController
                        constructorBytesSize=192
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    elif [[ $index -eq 1 ]]; then
                        contractName=TimelockController
                        constructorBytesSize=192
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    elif [[ $index -eq 2 ]]; then
                        contractName=GovernorAccessControlEmergency
                        constructorBytesSize=64
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    fi
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
                        constructorArgs="--constructor-args 0x"
                    fi
                elif [[ $contractName == "TransparentUpgradeableProxy" ]]; then
                    contractName=ProxyAdmin
                    constructorBytesSize=32
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                else
                    continue
                fi

                ((index++))

                verify_contract $contractAddress $contractName "$constructorArgs" "$@"
            done
        elif [[ $transactionType == "CREATE" && $verificationSuccessful != true ]]; then
            local initCode=$(echo $tx | jq -r '.transaction.input')

            if [ -d "out-euler-earn" ]; then
                # try to verify as EulerEarn contracts
                local src="lib/euler-earn/src"
                local verificationOptions="--num-of-optimizations 800 --compiler-version 0.8.27 --root lib/euler-earn"
                local compilerOptions="--optimize --optimizer-runs 800 --use 0.8.27"

                while true; do
                    case $eulerEarnIndex in
                        0)
                            # try to verify as EulerEarnVault
                            contractName=EulerEarnVault
                            constructorBytesSize=128
                            ;;
                        1)
                            # try to verify as Rewards
                            contractName=Rewards
                            constructorBytesSize=128
                            ;;
                        2)
                            # try to verify as Hooks
                            contractName=Hooks
                            constructorBytesSize=128
                            ;;
                        3)
                            # try to verify as Fee
                            contractName=Fee
                            constructorBytesSize=128
                            ;;
                        4)
                            # try to verify as Strategy
                            contractName=Strategy
                            constructorBytesSize=128
                            ;;
                        5)
                            # try to verify as WithdrawalQueue
                            contractName=WithdrawalQueue
                            constructorBytesSize=128
                            ;;
                        6)
                            # try to verify as EulerEarn
                            contractName=EulerEarn
                            constructorBytesSize=320
                            ;;
                        7)
                            # try to verify as EulerEarnFactory
                            contractName=EulerEarnFactory
                            constructorBytesSize=32
                            ;;
                        *)
                            break
                            ;;
                    esac

                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"

                    if [ "$createVerified" = false ]; then
                        forge clean && forge compile $src $compilerOptions
                    fi

                    verify_contract $contractAddress $contractName "$constructorArgs" "$@" $verificationOptions

                    if [ $? -eq 0 ]; then
                        createVerified=true
                        ((eulerEarnIndex++))
                        break
                    fi

                    ((eulerEarnIndex++))
                done
            fi
        fi
    done
}

input=$1
shift

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

if [ -d "$input" ]; then
    for fileName in "$input"/*.json; do
        if [ -f "$fileName" ]; then
            verify_broadcast $fileName "$@"
        fi
    done
else
    verify_broadcast $input "$@"
fi