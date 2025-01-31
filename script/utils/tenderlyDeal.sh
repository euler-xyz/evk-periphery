#!/bin/bash

account=$1
asset=$2
dealAmount=$3

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

if [[ $asset == "ETH" ]]; then
    decimals=18
    dealAmountCalc=$(echo "obase=16; $dealAmount * 10^$decimals" | bc)
    dealAmountHex="0x$(printf $dealAmountCalc)"

    jsonPayload=$(jq -n \
        --arg account "$account" \
        --arg dealAmountHex "$dealAmountHex" \
        '{
            "jsonrpc": "2.0",
            "method": "tenderly_setBalance",
            "params": [
                $account,
                $dealAmountHex
            ],
            "id": 1
        }')
else
    decimals=$(cast call $asset "decimals()(uint8)" --rpc-url $DEPLOYMENT_RPC_URL)
	dealAmountCalc=$(echo "obase=16; $dealAmount * 10^$decimals" | bc)
	dealAmountHex="0x$(printf $dealAmountCalc)"

    jsonPayload=$(jq -n \
		--arg account "$account" \
		--arg asset "$asset" \
		--arg dealAmountHex "$dealAmountHex" \
		'{
            "jsonrpc": "2.0",
            "method": "tenderly_setErc20Balance",
            "params": [
                $asset,
                $account,
                $dealAmountHex
            ],
            "id": 1
        }')
fi

echo "Dealing $asset to $account"
curl -s -X POST "$DEPLOYMENT_RPC_URL" -H "Content-Type: application/json" -d "$jsonPayload" > /dev/null
