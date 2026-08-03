#!/bin/bash

# .env.example ships DEPLOYMENT_RPC_URL as an empty assignment, so sourcing it would wipe an endpoint the caller
# already resolved and exported. Treat an empty value in .env as "not set" rather than as an override.
inherited_deployment_rpc_url=$DEPLOYMENT_RPC_URL
source .env
DEPLOYMENT_RPC_URL=${DEPLOYMENT_RPC_URL:-$inherited_deployment_rpc_url}

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
# shell-quoted: the caller consumes these lines with eval, where an unescaped space or apostrophe in the value would
# truncate the assignment, discard the arguments outright, or run whatever follows it
printf 'export SAFE_API_KEY=%q\n' "$SAFE_API_KEY"
printf 'export SCRIPT_ARGS=%q\n' "$SCRIPT_ARGS"

if [ "$DEPLOYMENT_RPC_URL" == "local" ]; then
    echo "export DEPLOYMENT_RPC_URL=http://127.0.0.1:8545"
    exit 0
fi

if ! cast chain-id --rpc-url "$DEPLOYMENT_RPC_URL" &>/dev/null; then
    env_var="DEPLOYMENT_RPC_URL_${DEPLOYMENT_RPC_URL}"

    if [ -n "${!env_var}" ]; then
        printf 'export DEPLOYMENT_RPC_URL=%q\n' "${!env_var}"
        exit 0
    else
        if ! chains_data=$(curl -fsSL https://chainid.network/chains_mini.json); then
            echo "determineArgs: could not fetch the chain list; '$DEPLOYMENT_RPC_URL' cannot be resolved" >&2
            chains_data="[]"
        fi

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
                # An exact name match wins. The subset match below accepts any name containing the search words, and
                # takes whichever the upstream list happens to put first: that resolves "linea" to "Zytron Linea
                # Mainnet", "berachain" to the "Berachain Bepolia" testnet and "morph" to "Morph Testnet".
                chain_id=$(echo "$chains_data" | jq -r --arg search "$network_name" '
                    [.[] | select((.name | ascii_downcase) == $search) | .chainId]
                    | if length == 1 then .[0] else empty end
                ')

                if [ -z "$chain_id" ]; then
                    chain_id=$(echo "$chains_data" | jq -r '
                        def words(str): str | ascii_downcase | split(" ");
                        def matches(network; search):
                            (words(search) - words(network)) | length == 0;
                        .[] | select(matches(.name; $search)) | .chainId
                    ' --arg search "$network_name" | head -n1)
                fi
            else
                chain_id=$network_name
            fi
        fi

        env_var="DEPLOYMENT_RPC_URL_${chain_id}"

        if [ -n "${!env_var}" ]; then
            printf 'export DEPLOYMENT_RPC_URL=%q\n' "${!env_var}"
            exit 0
        fi
    fi
fi

printf 'export DEPLOYMENT_RPC_URL=%q\n' "$DEPLOYMENT_RPC_URL"
