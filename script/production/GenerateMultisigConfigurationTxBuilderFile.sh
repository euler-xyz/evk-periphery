#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Generate multisig configuration transaction builder files."
    echo ""
    echo "OPTIONS:"
    echo "  --DAO                 Process only the DAO multisig"
    echo "  --securityCouncil     Process only the securityCouncil multisig"
    echo "  --labs                Process only the labs multisig"
    echo "  --securityPartnerA    Process only the securityPartnerA multisig"
    echo "  --securityPartnerB    Process only the securityPartnerB multisig"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "If no specific multisig is provided, all multisigs will be processed."
    echo ""
    echo "Available multisig keys: DAO, labs, securityCouncil, securityPartnerA, securityPartnerB"
}

# Parse command line arguments
selected_keys=()
all_multisigs=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --DAO)
            selected_keys+=('DAO')
            all_multisigs=false
            shift
            ;;
        --securityCouncil)
            selected_keys+=('securityCouncil')
            all_multisigs=false
            shift
            ;;
        --labs)
            selected_keys+=('labs')
            all_multisigs=false
            shift
            ;;
        --securityPartnerA)
            selected_keys+=('securityPartnerA')
            all_multisigs=false
            shift
            ;;
        --securityPartnerB)
            selected_keys+=('securityPartnerB')
            all_multisigs=false
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate selected keys
if [ "$all_multisigs" = false ]; then
    valid_keys=('DAO' 'labs' 'securityCouncil' 'securityPartnerA' 'securityPartnerB')
    for key in "${selected_keys[@]}"; do
        if [[ ! " ${valid_keys[@]} " =~ " ${key} " ]]; then
            echo "Error: Invalid multisig key '$key'"
            echo "Valid keys are: ${valid_keys[*]}"
            exit 1
        fi
    done
fi

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

chain_id=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$chain_id"
config_dir_path="${ADDRESSES_DIR_PATH%/}/../config/multisig"

# Set keys array based on selection
if [ "$all_multisigs" = true ]; then
    keys=('DAO' 'labs' 'securityCouncil' 'securityPartnerA' 'securityPartnerB')
    echo "Processing all multisigs: ${keys[*]}"
else
    keys=("${selected_keys[@]}")
    echo "Processing selected multisigs: ${keys[*]}"
fi

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

# Helper function to normalize addresses (convert to lowercase)
normalize_address() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Helper function to check if an address is in an array
is_address_in_array() {
    local target_addr="$1"
    shift
    local addresses=("$@")
    
    for addr in "${addresses[@]}"; do
        if [ "$(normalize_address "$target_addr")" == "$(normalize_address "$addr")" ]; then
            return 0
        fi
    done
    return 1
}


# Helper function to validate threshold
validate_threshold() {
    local threshold="$1"
    local owner_count="$2"
    
    if [ "$threshold" -lt 1 ]; then
        echo "Error: Threshold must be at least 1"
        return 1
    fi
    
    if [ "$threshold" -gt "$owner_count" ]; then
        echo "Error: Threshold ($threshold) cannot exceed number of owners ($owner_count)"
        return 1
    fi
    
    return 0
}

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
    
    # Parse current signers into array
    IFS=$'\n' read -d '' -r -a current_signers_array < <(echo "$current_signers" | grep -o "0x[a-fA-F0-9]\{40\}")
    current_signers_count=${#current_signers_array[@]}
    
    echo "Current state: $current_signers_count owners, threshold: $current_threshold"
    echo "Desired state: ${#desired_signers[@]} owners, threshold: $desired_threshold"
    
    # Resolve any non-address signers (multisig keys) to actual addresses
    for i in "${!desired_signers[@]}"; do
        signer="${desired_signers[$i]}"
        if [[ ! "$signer" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            resolved_signer=$(jq -r ".$signer" "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null || echo "$signer")
            desired_signers[$i]=$resolved_signer
        fi
    done
    
    # Set the createdFromOwnerAddress to address zero (for transaction signing)
    json=$(echo "$json" | jq --arg to "$multisig_address" --arg createdFromOwnerAddress "0x0000000000000000000000000000000000000000" \
            '.meta.createdFromOwnerAddress = $createdFromOwnerAddress')
    
    # Validate desired threshold
    if ! validate_threshold "$desired_threshold" "${#desired_signers[@]}"; then
        echo "Skipping $key due to invalid threshold configuration"
        echo ""
        continue
    fi
    
    # Phase 1: Add missing desired owners
    for desired_signer in "${desired_signers[@]}"; do
        if ! is_address_in_array "$desired_signer" "${current_signers_array[@]}"; then
            echo "Adding owner: $desired_signer"
            json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_addOwnerWithThreshold" \
                --arg owner "$desired_signer" --arg _threshold "$current_threshold" \
                '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"owner": $owner, "_threshold": $_threshold}}]' )
        fi
    done
    
    # Phase 2: Remove unwanted current owners
    # Create a list of owners to remove
    owners_to_remove=()
    for current_signer in "${current_signers_array[@]}"; do
        if ! is_address_in_array "$current_signer" "${desired_signers[@]}"; then
            owners_to_remove+=("$current_signer")
        fi
    done
    
    if [ ${#owners_to_remove[@]} -gt 0 ]; then
        # Create a working copy of the owners array to track changes
        working_owners_array=("${current_signers_array[@]}")
        
        # Strategy: Simulate linked list changes as we remove owners
        # IMPORTANT: After Phase 1 (adding owners), the linked list structure has changed!
        # New owners are added at the beginning of the list, so we need to account for this
        
        # Create a working copy that reflects the state AFTER Phase 1 additions
        # IMPORTANT: We need to simulate the exact order of addOwnerWithThreshold calls
        # Each call puts the new owner at the very beginning, so the last added owner is first
        
        # Start with original owners
        working_owners_array=("${current_signers_array[@]}")
        
        # Simulate each addOwnerWithThreshold call in the same order as Phase 1
        # Each call puts the new owner at the very beginning, so the last added owner is first
        for owner in "${desired_signers[@]}"; do
            if ! is_address_in_array "$owner" "${current_signers_array[@]}"; then
                # This owner was added in Phase 1, so it goes at the beginning
                working_owners_array=("$owner" "${working_owners_array[@]}")
            fi
        done
        
        # Remove owners in reverse order (end to beginning) to avoid affecting prevOwner of subsequent removals
        for ((i=${#owners_to_remove[@]}-1; i>=0; i--)); do
            owner_to_remove="${owners_to_remove[$i]}"
            
            # Find the index of this owner in the working_owners_array
            remove_index=-1
            for j in "${!working_owners_array[@]}"; do
                if [ "$(normalize_address "${working_owners_array[$j]}")" == "$(normalize_address "$owner_to_remove")" ]; then
                    remove_index=$j
                    break
                fi
            done
            
            if [ $remove_index -eq -1 ]; then
                echo "Warning: Could not find $owner_to_remove in working owners array, skipping"
                continue
            fi
            
            # Determine the previous owner based on position in working array
            if [ $remove_index -eq 0 ]; then
                # First owner, use SENTINEL_ADDRESS (0x1)
                prev_owner="0x0000000000000000000000000000000000000001"
            else
                # Previous owner is the one before in the working array
                prev_owner="${working_owners_array[$((remove_index - 1))]}"
            fi
            
            echo "Removing owner: $owner_to_remove"
            json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_removeOwner" \
                --arg owner "$owner_to_remove" --arg _threshold "$current_threshold" --arg prev_owner "$prev_owner" \
                '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"prevOwner": $prev_owner, "owner": $owner, "_threshold": $_threshold}}]' )
            
            # Simulate the linked list change: owners[prevOwner] = owners[owner]
            # This means prevOwner now points to whatever owner was pointing to
            # In our array representation, this means we remove the owner and shift everything
            
            # Remove the owner from our working array
            new_working_array=()
            for k in "${!working_owners_array[@]}"; do
                if [ $k -ne $remove_index ]; then
                    new_working_array+=("${working_owners_array[$k]}")
                fi
            done
            working_owners_array=("${new_working_array[@]}")
        done
    else
        echo "No owners need to be removed"
    fi
    
    # Phase 3: Adjust threshold if needed
    if [ "$current_threshold" -ne "$desired_threshold" ]; then
        echo "Setting threshold to $desired_threshold"
        json=$(echo $json | jq --arg to "$multisig_address" --argjson contractMethod "$contract_method_changeThreshold" \
            --arg _threshold "$desired_threshold" \
            '.transactions += [{"to": $to, "value": "0", "data": null, "contractMethod": $contractMethod, "contractInputsValues": {"_threshold": $_threshold}}]' )
    fi
    
    # Save the transaction batch if there are any transactions
    transaction_count=$(echo $json | jq '.transactions | length')
    if [ "$transaction_count" -gt 0 ]; then
        echo "Generated $transaction_count operations for $key multisig"
        echo $json | jq '.' > "${directory_path}/${key}.json"
    else
        echo "No operations needed for $key multisig (already in desired state)"
    fi
    echo ""
done
