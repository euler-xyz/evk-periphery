#!/bin/bash

# Store original foundry.toml src value
ORIGINAL_FOUNDRY_SRC="src"

function set_foundry_src {
    local src_path=$1
    sed -i.bak "s|^src = \".*\"|src = \"$src_path\"|" foundry.toml
    rm -f foundry.toml.bak
}

function restore_foundry_src {
    set_foundry_src "$ORIGINAL_FOUNDRY_SRC"
}

# Ensure foundry.toml is restored on exit/interrupt
trap restore_foundry_src EXIT

# Contracts that the deployment scripts deploy from separate builds (vm.getCode) have no name in the broadcast. They
# are recognised by their creation code, compared with a build made the way interactiveDeployment.sh makes it, so the
# compiler options below must stay in sync with that script.
# Fields: contract | source | compiler options | verification options | build directory
SEPARATELY_BUILT_CONTRACTS=(
    "GovernorAccessControlEmergencyFactoryV2|src/GovernorFactory/GovernorAccessControlEmergencyFactoryV2.sol|--optimize --optimizer-runs 10000 --use 0.8.24|--num-of-optimizations 10000 --compiler-version 0.8.24|out-governor-factory"
    "ERC4626EVCCollateralSecuritizeFactoryV2|src/VaultFactory/ERC4626EVCCollateralSecuritizeFactoryV2.sol|--optimize --optimizer-runs 10000 --use 0.8.24|--num-of-optimizations 10000 --compiler-version 0.8.24|out-securitize-factory"
    "EulerEarnFactory|lib/euler-earn/src|--via-ir --optimize --optimizer-runs 100 --use 0.8.26|--via-ir --num-of-optimizations 100 --compiler-version 0.8.26|out-euler-earn"
    "PublicAllocator|lib/euler-earn/src|--via-ir --optimize --optimizer-runs 100 --use 0.8.26|--via-ir --num-of-optimizations 100 --compiler-version 0.8.26|out-euler-earn"
    "EulerSwapProtocolFeeConfig|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
    "EulerSwapManagement|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
    "EulerSwap|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
    "EulerSwapFactory|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
    "EulerSwapPeriphery|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
    "EulerSwapRegistry|lib/euler-swap/src|--optimize --optimizer-runs 2500 --use 0.8.27|--num-of-optimizations 2500 --compiler-version 0.8.27|out-euler-swap"
)

# The metadata hashes of a build differ between machines (since forge 1.8 they cover absolute-path remappings), so a
# deployment built elsewhere is recognised with them left out. The explorer still compares the full code.
function mask_metadata_hashes {
    echo "$1" | tr 'A-F' 'a-f' | sed -E 's/a2646970667358221220[0-9a-f]{64}/<metadata hash>/g'
}

# Since forge 1.8 the metadata of a build holds absolute-path remappings that forge verify-contract does not submit, so
# the input is submitted with the remappings of the local artifact whose metadata hash matches the on-chain code.
function find_deployed_artifact {
    local contractAddress=$1
    local name=${2##*:}
    local onchainCode=$(cast code $contractAddress --rpc-url $DEPLOYMENT_RPC_URL 2>/dev/null)

    [[ ${#onchainCode} -lt 6 ]] && return 1

    local metadataTrailer=${onchainCode: -$((2 * 16#${onchainCode: -4} + 4))}
    local artifact

    for artifact in $(find out -path "*.sol/${name}.json" 2>/dev/null); do
        if [[ "$(jq -r '.deployedBytecode.object' "$artifact")" == *"$metadataTrailer" ]]; then
            echo "$artifact"
            return 0
        fi
    done

    return 1
}

function constructor_args_from_init_code {
    local fileName=$1
    local contractAddress=$2
    local contractName=$3
    local initCode=$4
    local arguments=$(jq -c --arg address "$contractAddress" \
        'first(.transactions[] | select(.contractAddress == $address)) | .arguments // []' "$fileName")
    local values=()
    local value artifact localBytecode types encoded

    while IFS= read -r value; do
        values+=("$value")
    done < <(echo "$arguments" | jq -r '.[]')

    for artifact in $(find out -path "*.sol/${contractName}.json" 2>/dev/null); do
        localBytecode=$(jq -r '.bytecode.object' "$artifact")

        if [[ ${#localBytecode} -gt 2 && "$initCode" == "$localBytecode"* ]]; then
            echo "${initCode:${#localBytecode}}"
            return 0
        fi

        types=$(jq -r 'def type: if (.type | startswith("tuple"))
            then "(\([.components[] | type] | join(",")))\(.type | ltrimstr("tuple"))" else .type end;
            [.abi[] | select(.type == "constructor") | .inputs[] | type] | join(",")' "$artifact")

        if [[ (-z $types && ${#values[@]} -gt 0) || (-n $types && ${#values[@]} -eq 0) ]]; then
            continue
        fi

        encoded=$(cast abi-encode "constructor($types)" "${values[@]}" 2>/dev/null) || continue

        if [[ "$initCode" == *"${encoded#0x}" ]]; then
            echo "${encoded#0x}"
            return 0
        fi
    done

    return 1
}

function submit_standard_json {
    local contractAddress=$1
    local encodedArgs=$2
    local artifact=$3
    local verifier_url=$4
    local verifier_api_key=$5
    shift 5

    local metadata=$(jq -c '.rawMetadata | fromjson' "$artifact")
    local target=$(echo "$metadata" | jq -r '.settings.compilationTarget | to_entries[0] | "\(.key):\(.value)"')
    local compilerVersion="v$(echo "$metadata" | jq -r '.compiler.version')"
    local inputFile=$(mktemp)

    forge verify-contract $contractAddress $target --show-standard-json-input --chain $chainId $@ 2>/dev/null \
        | jq --argjson metadata "$metadata" \
            '.settings.remappings = $metadata.settings.remappings | .settings.metadata = $metadata.settings.metadata
            | .settings.optimizer = $metadata.settings.optimizer | .settings.evmVersion = $metadata.settings.evmVersion' \
            > "$inputFile"

    echo "Submitting $target with the remappings of $artifact"

    local response result

    for _ in {1..12}; do
        response=$(curl -s -X POST "$verifier_url" \
            --data-urlencode "apikey=$verifier_api_key" \
            --data-urlencode "module=contract" \
            --data-urlencode "action=verifysourcecode" \
            --data-urlencode "contractaddress=$contractAddress" \
            --data-urlencode "sourceCode@$inputFile" \
            --data-urlencode "codeformat=solidity-standard-json-input" \
            --data-urlencode "contractname=$target" \
            --data-urlencode "compilerversion=$compilerVersion" \
            --data-urlencode "constructorArguements=${encodedArgs#0x}")
        result=$(echo "$response" | jq -r '(.result | strings) // .message // empty' 2>/dev/null)
        is_rate_limited "$result" || break
        sleep 5
    done
    rm -f "$inputFile"

    if [[ $(echo "$response" | jq -r '.status' 2>/dev/null) != "1" ]]; then
        echo "${result:-${response:0:200}}"
        is_already_verified "$result" && return 0
        return 1
    fi

    wait_for_verification $contractAddress ${target##*:} $result "$verifier_url" "$verifier_api_key"
}

# Explorers such as Routescan, and Etherscan on some chains (Arc), keep a submission queued for many minutes. A
# submission still queued after a short wait is checked again once every contract is submitted, so a slow queue neither
# holds up the remaining contracts nor reads as a failure.
PENDING_ADDRESSES=()
PENDING_NAMES=()
PENDING_GUIDS=()
PENDING_URLS=()
PENDING_KEYS=()

function queue_pending_verification {
    PENDING_ADDRESSES+=("$1")
    PENDING_NAMES+=("$2")
    PENDING_GUIDS+=("$3")
    PENDING_URLS+=("$4")
    PENDING_KEYS+=("$5")
    echo "Still queued on the explorer (GUID $3); checked again once every contract is submitted"
}

# Returns 0 when verified, 1 when failed and 2 while queued; the explorer's answer is left in $verification_result
function check_verification {
    local contractAddress=$1
    local guid=$2
    local verifier_url=$3
    local verifier_api_key=$4
    local separator="?"
    [[ "$verifier_url" == *"?"* ]] && separator="&"

    verification_result=$(curl -s "${verifier_url}${separator}module=contract&action=checkverifystatus&guid=${guid}&apikey=$verifier_api_key" \
        | jq -r '(.result | strings) // .message // empty' 2>/dev/null)

    # forge also keeps waiting on "contract does not exist": the explorer has not indexed the contract yet
    if [[ -z $verification_result || $verification_result == *"Pending"* \
        || $verification_result == "Error: contract does not exist"* ]] || is_rate_limited "$verification_result"; then
        return 2
    fi

    if [[ $verification_result == "Pass - Verified" ]] || is_already_verified "$verification_result"; then
        return 0
    fi

    # Blockscout drops a finished job, so its outcome is only visible on the contract
    if [[ $verification_result == "Unknown UID" ]] \
        && is_verified_on_explorer $contractAddress "$verifier_url" "$verifier_api_key" > /dev/null; then
        verification_result="Verified"
        return 0
    fi

    return 1
}

# Returns 0 when verified, 1 when failed and 2 when still queued after about 30 seconds
function wait_for_verification {
    local contractAddress=$1
    local contractName=$2
    local guid=$3
    local verifier_url=$4
    local verifier_api_key=$5
    local status

    for _ in {1..6}; do
        sleep 5
        check_verification $contractAddress $guid "$verifier_url" "$verifier_api_key"
        status=$?
        echo "$verification_result"
        [[ $status -ne 2 ]] && return $status
    done

    queue_pending_verification $contractAddress $contractName $guid "$verifier_url" "$verifier_api_key"
    return 2
}

function verify_proxy_on_explorer {
    local contractAddress=$1
    local contractName=$2
    local verifier_url=$3
    local verifier_api_key=$4

    if [[ $contractName == *Proxy* && $verifier_url == *scan*/api* ]]; then
        local separator="?"
        [[ "$verifier_url" == *"?"* ]] && separator="&"
        curl -s -d "address=$contractAddress" "${verifier_url}${separator}module=contract&action=verifyproxycontract&apikey=$verifier_api_key"
        echo ""
    fi
}

function await_pending_verifications {
    local count=${#PENDING_GUIDS[@]}
    [[ $count -eq 0 ]] && return 0

    local timeout=${VERIFICATION_TIMEOUT:-1800}

    if ! [[ $timeout =~ ^[0-9]+$ ]]; then
        echo "! VERIFICATION_TIMEOUT must be a number of seconds, not '$timeout'; using 1800"
        timeout=1800
    fi

    local deadline=$((SECONDS + timeout))
    local remaining=$count
    local interrupted=false
    local states=()
    local i status

    for ((i = 0; i < count; i++)); do
        states[i]=pending
    done

    echo ""
    echo "Checking $count queued verifications again for up to $(((timeout + 59) / 60)) min (VERIFICATION_TIMEOUT=$timeout). Ctrl-C stops waiting."

    # Handling Ctrl-C here, rather than dying of it, lets a calling deployment script carry on and save its records
    trap 'interrupted=true' INT

    while [[ $remaining -gt 0 && $SECONDS -lt $deadline && $interrupted == false ]]; do
        sleep 15

        for ((i = 0; i < count; i++)); do
            [[ $interrupted == true ]] && break
            [[ ${states[i]} == pending ]] || continue
            check_verification ${PENDING_ADDRESSES[i]} ${PENDING_GUIDS[i]} "${PENDING_URLS[i]}" "${PENDING_KEYS[i]}"
            status=$?
            sleep 1
            [[ $status -eq 2 ]] && continue

            remaining=$((remaining - 1))

            if [[ $status -eq 0 ]]; then
                states[i]=verified
                echo "Verified ${PENDING_NAMES[i]}: ${PENDING_ADDRESSES[i]}"
                verify_proxy_on_explorer ${PENDING_ADDRESSES[i]} ${PENDING_NAMES[i]} "${PENDING_URLS[i]}" "${PENDING_KEYS[i]}"
            else
                states[i]=failed
                echo "! Verification of ${PENDING_NAMES[i]} at ${PENDING_ADDRESSES[i]} failed: $verification_result"
            fi
        done
    done

    trap - INT
    [[ $remaining -eq 0 ]] && ! [[ " ${states[*]} " == *" failed "* ]] && return 0

    echo ""
    echo "Not verified:"

    for ((i = 0; i < count; i++)); do
        case ${states[i]} in
            failed) echo "  ${PENDING_NAMES[i]} ${PENDING_ADDRESSES[i]}: failed" ;;
            pending) echo "  ${PENDING_NAMES[i]} ${PENDING_ADDRESSES[i]}: still queued (GUID ${PENDING_GUIDS[i]})" ;;
        esac
    done

    [[ $remaining -gt 0 ]] && echo "Queued submissions may still pass. Run this script again later: contracts verified by then are reported as already verified."
    return 1
}

function is_rate_limited {
    [[ $1 == *[Tt]"oo "[Mm]"any "[Rr]"equests"* || $1 == *[Rr]"ate "[Ll]"imit"* ]]
}

function is_already_verified {
    [[ $1 == *[Aa]"lready "[Vv]"erified"* ]]
}

function is_verified_on_explorer {
    local contractAddress=$1
    local verifier_url=$2
    local verifier_api_key=$3
    local separator="?"
    [[ "$verifier_url" == *"?"* ]] && separator="&"
    local response

    for _ in {1..12}; do
        response=$(curl -s "${verifier_url}${separator}module=contract&action=getsourcecode&address=${contractAddress}&apikey=$verifier_api_key")

        if [[ -n $(echo "$response" | jq -r '.result[0].SourceCode // empty' 2>/dev/null) ]]; then
            echo "Verified"
            return 0
        fi

        is_rate_limited "$(echo "$response" | jq -r '(.result | strings) // .message // empty' 2>/dev/null)" || return 1
        sleep 5
    done

    return 1
}

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

    # Monad mainnet (143) is not in foundry's chain registry, so the native
    # `etherscan` verifier cannot resolve it ("Chain 143 not supported"). Fall back
    # to the `custom` verifier, which is driven against the Etherscan V2 endpoint
    # with the API key embedded in the URL (see the `custom` branch below).
    if [[ "$chainId" == "143" && "$verifier" == "etherscan" ]]; then
        verifier="custom"
    fi

    if [[ $VERIFIER_URL == "" ]]; then
        verifier_api_key=${!verifier_api_key_var}
    else
        verifier_api_key=$VERIFIER_API_KEY
    fi

    echo "Verifying $contractName: $contractAddress"

    local artifact

    if [[ $verifier != "sourcify" && $constructorArgs != "--guess-constructor-args" ]] \
        && artifact=$(find_deployed_artifact $contractAddress $contractName) \
        && jq -e '.rawMetadata | fromjson | .settings.remappings | any(startswith("/"))' "$artifact" > /dev/null; then
        submit_standard_json $contractAddress "${constructorArgs#--constructor-args }" "$artifact" "$verifier_url" "$verifier_api_key" $@
        result=$?
        [[ $result -eq 0 ]] && verify_proxy_on_explorer $contractAddress $contractName "$verifier_url" "$verifier_api_key"
        return $result
    fi

    local verifierArgs="--verifier-url $verifier_url"

    if [[ $verifier == "blockscout" ]]; then
        verifierArgs="$verifierArgs --verifier-api-key ${verifier_api_key:-\"\"} --verifier=blockscout"

        if [[ $constructorArgs == "--guess-constructor-args" ]]; then
            constructorArgs=""
        fi
    elif [[ $verifier == "sourcify" ]]; then
        verifierArgs="$verifierArgs --verifier=$verifier --retries 1"
    elif [[ $verifier == "custom" ]]; then
        # foundry's `custom` verifier ignores --verifier-api-key, so when a key is
        # configured (Etherscan V2 chains such as Monad, which foundry doesn't know
        # natively) embed it directly in the URL. Etherscan V2 honors the first apikey
        # query param, so this works even if foundry appends an empty one. Use '&' or
        # '?' depending on whether the URL already carries a query string (the
        # Etherscan V2 chainid does). Key-less custom explorers (routescan/snowtrace)
        # keep an empty key and are therefore unaffected.
        local apiKeyQuery=""
        if [[ -n $verifier_api_key ]]; then
            local keySeparator="?"
            [[ "$verifier_url" == *"?"* ]] && keySeparator="&"
            apiKeyQuery="${keySeparator}apikey=${verifier_api_key}"
        fi
        verifierArgs="--verifier-url ${verifier_url}${apiKeyQuery} --verifier=$verifier"

        if [[ $constructorArgs == "--guess-constructor-args" ]]; then
            constructorArgs=""
        fi
    else
        verifierArgs="$verifierArgs --verifier-api-key $verifier_api_key --verifier=$verifier"
    fi

    # forge's status is recorded out of band: $? after the pipeline reports tee's status, not forge's, so every
    # verification failure would otherwise be read as success. Not using pipefail because tee itself fails without a tty.
    local statusFile
    statusFile=$(mktemp)

    output=$({ env VERIFIER_API_KEY=$verifier_api_key ETHERSCAN_API_KEY=$verifier_api_key \
        forge verify-contract $contractAddress $contractName $constructorArgs --rpc-url $DEPLOYMENT_RPC_URL --chain $chainId $verifierArgs --watch $@ 2>&1; echo $? > "$statusFile"; } | tee /dev/tty) #--show-standard-json-input > $contractAddress.json

    result=$(cat "$statusFile" 2>/dev/null)
    rm -f "$statusFile"
    # forge exits 2 on argument errors; 2 is kept for a submission still queued
    [[ $result != 0 ]] && result=1

    if [[ $verifier == "sourcify" ]] && echo "$output" | grep -q "is already partially verified"; then
        echo "Contract already partially verified, continuing..."
        result=0
    fi

    local guid=$(echo "$output" | sed -n 's/.*GUID: `\([^`]*\)`.*/\1/p' | tail -1)

    if [[ $result -ne 0 && $output == *"still pending"* && -n $guid && -n $verifier_url ]]; then
        queue_pending_verification $contractAddress ${contractName##*:} $guid "$verifier_url" "$verifier_api_key"
        result=2
    fi

    [[ $result -eq 0 ]] && verify_proxy_on_explorer $contractAddress $contractName "$verifier_url" "$verifier_api_key"
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

            # --guess-constructor-args relies on an explorer lookup of the creation transaction, which fails on some chains
            constructorArgs="--guess-constructor-args"
            local encodedArgs

            if encodedArgs=$(constructor_args_from_init_code $fileName $contractAddress $contractName $initCode); then
                constructorArgs=${encodedArgs:+--constructor-args 0x$encodedArgs}
            fi

            if [[ $contractName == "OFTAdapterUpgradeable" ]]; then
                contractName="./src/OFT/OFTAdapterUpgradeable.sol:OFTAdapterUpgradeable"
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
                local verificationOptions=""
                local transactionType=$(echo $contract | jq -r '.transactionType')
                local contractAddress=$(echo $contract | jq -r '.address')
                local initCode=$(echo $contract | jq -r '.initCode')

                if [[ $contractName == "EulerKinkIRMFactory" || $function == "deploy(uint256,uint256,uint256,uint32)" ]]; then
                    contractName=IRMLinearKink
                    constructorBytesSize=128
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "EulerKinkyIRMFactory" || $function == "deploy(uint256,uint256,uint256,uint32,uint256)" ]]; then
                    contractName=IRMLinearKink
                    constructorBytesSize=160
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "EulerIRMAdaptiveCurveFactory" || $function == "deploy(int256,int256,int256,int256,int256,int256)" ]]; then
                    contractName=IRMAdaptiveCurve
                    constructorBytesSize=192
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "EulerRouterFactory" || $function == "deploy(address)" ]]; then
                    contractName=EulerRouter
                    constructorBytesSize=64
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                elif [[ $contractName == "GovernorAccessControlEmergencyFactoryV2" || $function == "deploy((uint256,address[],address[],address[]),(uint256,address[],address[],address[]),address[])" ]]; then
                    # The V2 governor factory is built with 10,000 optimizer runs, and so is the code it deploys
                    verificationOptions="--num-of-optimizations 10000 --compiler-version 0.8.24"

                    if [[ $index -eq 0 ]]; then
                        forge clean && forge compile src/GovernorFactory/GovernorAccessControlEmergencyFactoryV2.sol --optimize --optimizer-runs 10000 --use 0.8.24
                        createVerified=true
                        contractName=TimelockController
                        constructorBytesSize=192
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    elif [[ $index -eq 1 ]]; then
                        contractName=TimelockController
                        constructorBytesSize=192
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    elif [[ $index -eq 2 ]]; then
                        contractName=GovernorAccessControlEmergencyV2
                        constructorBytesSize=64
                        constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                    fi
                elif [[ $contractName == "CapRiskStewardFactory" || $function == "deploy(address,address,address)" ]]; then
                    contractName=CapRiskSteward
                    constructorBytesSize=160
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
                        constructorArgs="--constructor-args 0x"
                    fi
                elif [[ $contractName == "TransparentUpgradeableProxy" ]]; then
                    contractName=ProxyAdmin
                    constructorBytesSize=32
                    constructorArgs="--constructor-args ${initCode: -$((2*constructorBytesSize))}"
                else
                    continue
                fi

                index=$((index + 1))

                verify_contract $contractAddress $contractName "$constructorArgs" "$@" $verificationOptions
            done
        elif [[ $transactionType == "CREATE" && $verificationSuccessful != true ]]; then
            local initCode=$(echo $tx | jq -r '.transaction.input')
            local identified=false

            for entry in "${SEPARATELY_BUILT_CONTRACTS[@]}"; do
                local name src compilerOptions verificationOptions buildDir
                IFS='|' read -r name src compilerOptions verificationOptions buildDir <<< "$entry"
                local artifact="$buildDir/$name.sol/$name.json"

                if [ ! -f "$artifact" ]; then
                    forge compile $src $compilerOptions --out $buildDir --force > /dev/null
                fi

                local bytecode=$(jq -r '.bytecode.object' "$artifact" 2>/dev/null)
                bytecode=${bytecode#0x}
                local deployedPrefix=${initCode#0x}
                deployedPrefix=${deployedPrefix:0:${#bytecode}}

                if [[ -z "$bytecode" || "$(mask_metadata_hashes "$deployedPrefix")" != "$(mask_metadata_hashes "$bytecode")" ]]; then
                    continue
                fi

                identified=true
                local encodedArgs=${initCode#0x}
                encodedArgs=${encodedArgs:${#bytecode}}

                if [ -z "$encodedArgs" ]; then
                    constructorArgs=""
                else
                    constructorArgs="--constructor-args $encodedArgs"
                fi

                if [ -d "$src" ]; then
                    set_foundry_src "$src"
                    contractName=$name
                else
                    contractName="$src:$name"
                fi

                forge clean && forge compile $src $compilerOptions
                createVerified=true
                verify_contract $contractAddress $contractName "$constructorArgs" "$@" $verificationOptions

                restore_foundry_src
                break
            done

            if [[ "$identified" = false && $contractName == null ]]; then
                echo "! Could not identify the contract created at $contractAddress. Verify it manually."
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

status=$?
# a contract still queued is accounted for by await_pending_verifications
[[ $status -eq 2 ]] && status=0
await_pending_verifications || status=1
exit $status