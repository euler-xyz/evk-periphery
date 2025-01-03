#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval "set -- $SCRIPT_ARGS"

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

chain_id=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$chain_id"
config_dir_path="${ADDRESSES_DIR_PATH%/}/../config/multisig"
keys=('DAO' 'labs' 'securityCouncil')

contract_method_addOwnerWithThreshold=$(jq -n '{
  contractMethod: {
    inputs: [
      {internalType: "address", name: "owner", type: "address"},
      {internalType: "uint256", name: "_threshold", type: "uint256"}
    ],
    name: "addOwnerWithThreshold",
    payable: false
  }
}' | jq -c '.contractMethod')

contract_method_removeOwner=$(jq -n '{
  contractMethod: {
    inputs: [
      {internalType: "address", name: "prevOwner", type: "address"},
      {internalType: "address", name: "owner", type: "address"}, 
      {internalType: "uint256", name: "_threshold", type: "uint256"}
    ],
    name: "removeOwner",
    payable: false
  }
}' | jq -c '.contractMethod')

contract_method_changeThreshold=$(jq -n '{
  contractMethod: {
    inputs: [
      {internalType: "uint256", name: "_threshold", type: "uint256"}
    ],
    name: "changeThreshold",
    payable: false
  }
}' | jq -c '.contractMethod')

read -p "Provide the directory name to save the results (default: default): " directory_name
directory_name=${directory_name:-default}
directory_path="script/deployments/$directory_name/$chain_id/output"
mkdir -p "$directory_path"

for key in "${keys[@]}"; do
    multisig_address=$(jq -r ".$key" "$addresses_dir_path/MultisigAddresses.json")
    desired_threshold=$(jq -r ".threshold" "$config_dir_path/${key}.json")
    IFS=$'\n' read -d '' -r -a desired_signers < <(jq -r '.signers[]' "$config_dir_path/${key}.json")
    json='{"chainId":"'$chain_id'","createdAt":'$(date +%s)',"meta":{"name":"'"$key"' multisig configuration batch","createdFromSafeAddress":"'"$multisig_address"'"},"transactions":[]}'

    echo "Processing $key multisig at address: $multisig_address"
    current_threshold=$(cast call $multisig_address "getThreshold()(uint256)" --rpc-url $DEPLOYMENT_RPC_URL)
    current_signers=$(cast call $multisig_address "getOwners()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
    current_signer_is_desired=false

    if [ $(echo "$current_signers" | grep -o "0x" | wc -l) -gt 1 ]; then
        echo "Error: This script is meant for initial multisig setup, but it already has more than one signer. Skipping..."
        echo ""
        continue
    fi

    current_signer=$(echo "$current_signers" | grep -o "0x[a-fA-F0-9]\{40\}" | head -n 1)
    json=$(echo "$json" | jq --arg to "$multisig_address" --arg createdFromOwnerAddress "$current_signer" \
            '.meta.createdFromOwnerAddress = $createdFromOwnerAddress')

    for signer in "${desired_signers[@]}"; do
        if [[ ! "$signer" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            signer=$(jq -r ".$signer" "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null || echo "$signer")
        fi

        echo "Adding signer: $signer"
        json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_addOwnerWithThreshold" \
            --arg owner "$signer" --arg _threshold "$current_threshold" \
            '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"owner": $owner, "_threshold": $_threshold}}]' )

        if [ "$current_signer_is_desired" == false ]; then
            current_signer_is_desired=$([ "$(echo "$signer" | tr '[:upper:]' '[:lower:]')" = "$(echo "$current_signer" | tr '[:upper:]' '[:lower:]')" ] \
                && echo true || echo false)
        fi
    done

    if [ "$current_threshold" -ne "$desired_threshold" ]; then
        echo "Setting threshold to $desired_threshold"
    fi

    if [ "$current_signer_is_desired" = true ]; then
        json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_changeThreshold" \
            --arg _threshold "$desired_threshold" \
            '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"_threshold": $_threshold}}]' )
    else
        echo "Removing current signer"
        json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_removeOwner" \
            --arg current_signer "$current_signer" --arg _threshold "$desired_threshold" \
            '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"prevOwner": "0x0000000000000000000000000000000000000001", "owner": $current_signer, "_threshold": $_threshold}}]' )
    fi

    if [ "$(echo $json | jq '.transactions | length')" -gt 0 ]; then
        echo $json | jq '.' > "${directory_path}/${key}.json"
    else
        echo "No transactions to execute for $key multisig"
    fi
    echo ""
done
