#!/bin/bash

source .env

rpc_url=$(echo "$@" | grep -o '\--rpc-url [^ ]*' | cut -d ' ' -f 2)

if echo "$@" | grep -q '\--test-addresses'; then
    EXPORT_ENV_VARS="export ADDRESSES_DIR_PATH=../euler-interfaces/addresses/test"
else
    EXPORT_ENV_VARS="export ADDRESSES_DIR_PATH=../euler-interfaces/addresses"
fi

SCRIPT_ARGS=$(echo "$@" | sed 's/--rpc-url [^ ]* *//' | sed 's/--test-addresses *//')

if [ -z "$DEPLOYMENT_RPC_URL" ] && [ -n "$rpc_url" ]; then
    DEPLOYMENT_RPC_URL=$rpc_url
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    exit 1
fi

echo "$EXPORT_ENV_VARS"
echo "export SAFE_API_KEY=$SAFE_API_KEY"
echo "export SCRIPT_ARGS='$SCRIPT_ARGS'"

if [ "$DEPLOYMENT_RPC_URL" == "local" ]; then
    echo "export DEPLOYMENT_RPC_URL=http://127.0.0.1:8545"
    exit 0
fi

if ! cast chain-id --rpc-url "$DEPLOYMENT_RPC_URL" &>/dev/null; then
    env_var="DEPLOYMENT_RPC_URL_${DEPLOYMENT_RPC_URL}"

    if [ -n "${!env_var}" ]; then
        echo "export DEPLOYMENT_RPC_URL=${!env_var}"
        exit 0
    else
        chains_data=$(curl -s https://chainid.network/chains_mini.json)

        # Networks not in chainid.network - direct chain ID mapping
        case $(echo "$DEPLOYMENT_RPC_URL" | tr '[:upper:]' '[:lower:]') in
            hyperevm|hyper) chain_id=999 ;;
            *) chain_id="" ;;
        esac

        if [ -z "$chain_id" ]; then
            case $(echo "$DEPLOYMENT_RPC_URL" | tr '[:upper:]' '[:lower:]') in
                mainnet|ethereum) network_name="ethereum mainnet" ;;
                optimism|op) network_name="op mainnet" ;;
                arbitrum|arb) network_name="arbitrum one" ;;
                avalanche|avax) network_name="avalanche c-chain" ;;
                swell) network_name="swellchain" ;;
                polygon|matic) network_name="polygon mainnet" ;;
                gnosis|xdai) network_name="gnosis" ;;
                bsc|bnb) network_name="bnb smart chain mainnet" ;;
                linea) network_name="linea" ;;
                berachain|bera) network_name="berachain" ;;
                mantle) network_name="mantle" ;;
                worldchain|world) network_name="world chain" ;;
                ink) network_name="ink" ;;
                bob) network_name="bob" ;;
                sonic) network_name="sonic mainnet" ;;
                unichain|uni) network_name="unichain" ;;
                corn) network_name="corn" ;;
                morph) network_name="morph" ;;
                rootstock|rsk) network_name="rootstock mainnet" ;;
                plasma) network_name="plasma mainnet" ;;
                tac) network_name="tac mainnet" ;;
                monad) network_name="monad" ;;
                *) network_name=$(echo "$DEPLOYMENT_RPC_URL" | tr '[:upper:]' '[:lower:]') ;;
            esac
        fi
        
        if [ -z "$chain_id" ]; then
            if ! [[ "$network_name" =~ ^[0-9]+$ ]]; then
                chain_id=$(echo "$chains_data" | jq -r '
                    def words(str): str | ascii_downcase | split(" ");
                    def matches(network; search): 
                        (words(search) - words(network)) | length == 0;
                    .[] | select(matches(.name; $search)) | .chainId
                ' --arg search "$network_name" | head -n1)
            else
                chain_id=$network_name
            fi
        fi

        env_var="DEPLOYMENT_RPC_URL_${chain_id}"

        if [ -n "${!env_var}" ]; then
            echo "export DEPLOYMENT_RPC_URL=${!env_var}"
            exit 0
        fi
    fi
fi

echo "export DEPLOYMENT_RPC_URL=$DEPLOYMENT_RPC_URL"
