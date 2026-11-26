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
    echo "  --safe-address VALUE  Process only the specified multisig"
    echo "                        VALUE can be either:"
    echo "                        - A multisig key (e.g., DAO, labs, securityCouncil, riskSteward, etc.)"
    echo "                        - An actual address (0x...)"
    echo "  --safe-nonce VALUE    Safe nonce to name the file with (requires exactly one --safe-address)"
    echo "                        Default: the Safe's current on-chain nonce. Batches from the forge scripts use the"
    echo "                        Safe service's next nonce, which is later when transactions are queued; pass that"
    echo "                        nonce here so the batches merge"
    echo "  --help, -h            Show this help message"
    echo ""
    echo "If no specific multisig is provided, all multisigs will be processed."
    echo ""
    echo "Each file is saved as SafeBatchBuilder_<nonce>_<safe>_<i>.json, so MergeSafeBatchBuilderFiles can merge it"
    echo "with other batches for the same Safe and nonce. A re-run replaces its own previous file."
    echo ""
    echo "Available multisig keys are read from MultisigAddresses.json files in:"
    echo "  - addresses/[chain_id]/MultisigAddresses.json"
    echo "  - config/addresses/[chain_id]/MultisigAddresses.json"
}

# Helper function to check if a string is an Ethereum address
is_address() {
    local input="$1"
    if [[ "$input" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Helper function to normalize addresses (convert to lowercase)
normalize_address() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Parse command line arguments
selected_keys=()
selected_addresses=()
all_multisigs=true
safe_nonce=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --safe-address)
            if [[ $# -lt 2 ]]; then
                echo "Error: --safe-address requires a multisig key or address"
                echo "Use --help for usage information."
                exit 1
            fi
            if is_address "$2"; then
                selected_addresses+=("$2")
            else
                selected_keys+=("$2")
            fi
            all_multisigs=false
            shift 2
            ;;
        --safe-nonce)
            if [[ $# -lt 2 || ! "$2" =~ ^(0|[1-9][0-9]*)$ ]]; then
                echo "Error: --safe-nonce requires a number without leading zeros"
                exit 1
            fi
            safe_nonce="$2"
            shift 2
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

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

chain_id=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$chain_id"
config_dir_path="${ADDRESSES_DIR_PATH%/}/../config/multisig"
multisig_addresses_file="$addresses_dir_path/MultisigAddresses.json"
config_multisig_addresses_file="${ADDRESSES_DIR_PATH%/}/../config/addresses/$chain_id/MultisigAddresses.json"

# Validate that at least one MultisigAddresses.json exists
if [ ! -f "$multisig_addresses_file" ] && [ ! -f "$config_multisig_addresses_file" ]; then
    echo "Error: MultisigAddresses.json not found in either:"
    echo "  - $multisig_addresses_file"
    echo "  - $config_multisig_addresses_file"
    exit 1
fi

# Helper function to get a value from MultisigAddresses.json (checks both locations)
get_multisig_address() {
    local key="$1"
    local result=""
    
    # Try main addresses directory first
    if [ -f "$multisig_addresses_file" ]; then
        result=$(jq -r ".$key" "$multisig_addresses_file" 2>/dev/null)
        if [ "$result" != "null" ] && [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Try config addresses directory
    if [ -f "$config_multisig_addresses_file" ]; then
        result=$(jq -r ".$key" "$config_multisig_addresses_file" 2>/dev/null)
        if [ "$result" != "null" ] && [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Return empty if not found
    echo ""
    return 1
}

# Resolve addresses to keys
if [ ${#selected_addresses[@]} -gt 0 ]; then
    echo "Resolving addresses to multisig keys..."
    for addr in "${selected_addresses[@]}"; do
        # Normalize the address to lowercase for comparison
        normalized_addr=$(normalize_address "$addr")
        
        # Search for the address in both MultisigAddresses.json files
        found_key=""
        
        # First, check the main addresses directory
        if [ -f "$multisig_addresses_file" ]; then
            found_key=$(jq -r --arg addr "$normalized_addr" '
                to_entries[] | 
                select(.value | ascii_downcase == $addr) | 
                .key
            ' "$multisig_addresses_file" 2>/dev/null | head -n 1)
        fi
        
        # If not found, check the config addresses directory
        if [ -z "$found_key" ] && [ -f "$config_multisig_addresses_file" ]; then
            found_key=$(jq -r --arg addr "$normalized_addr" '
                to_entries[] | 
                select(.value | ascii_downcase == $addr) | 
                .key
            ' "$config_multisig_addresses_file" 2>/dev/null | head -n 1)
        fi
        
        if [ -z "$found_key" ]; then
            echo "Error: Address $addr not found in MultisigAddresses.json"
            echo "Available addresses:"
            if [ -f "$multisig_addresses_file" ]; then
                echo "  From $multisig_addresses_file:"
                jq -r 'to_entries[] | "    \(.key): \(.value)"' "$multisig_addresses_file"
            fi
            if [ -f "$config_multisig_addresses_file" ]; then
                echo "  From $config_multisig_addresses_file:"
                jq -r 'to_entries[] | "    \(.key): \(.value)"' "$config_multisig_addresses_file"
            fi
            exit 1
        fi
        
        echo "  $addr -> $found_key"
        selected_keys+=("$found_key")
    done
fi

# Validate selected keys by checking if they exist in MultisigAddresses.json files
if [ "$all_multisigs" = false ]; then
    for key in "${selected_keys[@]}"; do
        # Check if the key exists in either MultisigAddresses.json file
        key_address=$(get_multisig_address "$key")
        if [ -z "$key_address" ]; then
            echo "Error: Multisig key '$key' not found in MultisigAddresses.json"
            echo "Available keys:"
            if [ -f "$multisig_addresses_file" ]; then
                echo "  From $multisig_addresses_file:"
                jq -r 'keys[]' "$multisig_addresses_file" 2>/dev/null | sed 's/^/    /'
            fi
            if [ -f "$config_multisig_addresses_file" ]; then
                echo "  From $config_multisig_addresses_file:"
                jq -r 'keys[]' "$config_multisig_addresses_file" 2>/dev/null | sed 's/^/    /'
            fi
            exit 1
        fi
    done
    
    # Remove duplicates from selected_keys
    unique_keys=()
    for key in "${selected_keys[@]}"; do
        if [[ ! " ${unique_keys[@]} " =~ " ${key} " ]]; then
            unique_keys+=("$key")
        fi
    done
    selected_keys=("${unique_keys[@]}")
fi

# Set keys array based on selection
if [ "$all_multisigs" = true ]; then
    # Collect all unique keys from both MultisigAddresses.json files
    keys=()
    if [ -f "$multisig_addresses_file" ]; then
        while IFS= read -r key; do
            keys+=("$key")
        done < <(jq -r 'keys[]' "$multisig_addresses_file" 2>/dev/null)
    fi
    if [ -f "$config_multisig_addresses_file" ]; then
        while IFS= read -r key; do
            # Only add if not already in the array
            if [[ ! " ${keys[@]} " =~ " ${key} " ]]; then
                keys+=("$key")
            fi
        done < <(jq -r 'keys[]' "$config_multisig_addresses_file" 2>/dev/null)
    fi
    
    if [ ${#keys[@]} -eq 0 ]; then
        echo "Error: No multisig keys found in MultisigAddresses.json files"
        exit 1
    fi
    
    echo "Processing all multisigs: ${keys[*]}"
else
    keys=("${selected_keys[@]}")
    echo "Processing selected multisigs: ${keys[*]}"
fi

if [ -n "$safe_nonce" ] && [ ${#keys[@]} -ne 1 ]; then
    echo "Error: --safe-nonce applies to a single Safe; select exactly one with --safe-address"
    exit 1
fi

# Appends a raw-calldata call on the Safe itself, the format MergeSafeBatchBuilderFiles reads
append_safe_call() {
    local data
    if ! data=$(cast calldata "$@"); then
        echo "Error: could not encode $1 for $key"
        exit 1
    fi
    json=$(echo "$json" | jq --arg to "$multisig_address" --arg data "$data" \
        '.transactions += [{"to": $to, "value": "0", "data": $data}]')
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

stale_batch=""
processed_safes=()

# A previous batch for a Safe that this run skipped or found already configured would otherwise still get merged
drop_stale_batch() {
    [ -n "$stale_batch" ] || return 0
    local prefix=${stale_batch%_*}
    local removed_index=${stale_batch##*_}
    removed_index=${removed_index%.json}
    rm "$stale_batch"
    echo "Removed the outdated $(basename "$stale_batch")"
    local later_file index warned=false
    for later_file in "$prefix"_*.json; do
        index=${later_file#"${prefix}_"}
        index=${index%.json}
        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -gt "$removed_index" ]; then
            if [ "$warned" = false ]; then
                echo "Warning: MergeSafeBatchBuilderFiles stops at the missing index $removed_index. Renumber these later"
                echo "files to close the gap, leaving out earlier merge outputs:"
                warned=true
            fi
            echo "    $(basename "$later_file"): $(jq -r '"\(.meta.name // "?") (\(.transactions | length) calls)"' "$later_file" 2>/dev/null)"
        fi
    done
    echo ""
    stale_batch=""
}

for key in "${keys[@]}"; do
    drop_stale_batch
    multisig_address=$(get_multisig_address "$key")
    if [ -z "$multisig_address" ]; then
        echo "Error: Could not find address for multisig key '$key' in either MultisigAddresses.json file"
        echo "Skipping $key"
        echo ""
        continue
    fi
    if [ ! -f "$config_dir_path/${key}.json" ]; then
        echo "No config/multisig/${key}.json, skipping $key"
        echo ""
        continue
    fi
    multisig_address=$(cast to-check-sum-address "$multisig_address")
    if is_address_in_array "$multisig_address" "${processed_safes[@]}"; then
        echo "Error: $key is $multisig_address, which this run already processed under another key"
        echo "Skipping $key"
        echo ""
        continue
    fi
    processed_safes+=("$multisig_address")
    nonce=${safe_nonce:-$(cast call "$multisig_address" "nonce()(uint256)" --rpc-url $DEPLOYMENT_RPC_URL 2>/dev/null | awk '{print $1}')}
    if ! [[ "$nonce" =~ ^(0|[1-9][0-9]*)$ ]]; then
        echo "Error: could not read the nonce of $key ($multisig_address)"
        echo "Skipping $key"
        echo ""
        continue
    fi

    # File names must match MergeSafeBatchBuilderFiles: SafeBatchBuilder_<nonce>_<checksummed safe>_<i>.json
    batch_name="$key multisig configuration batch"
    batch_prefix="$directory_path/SafeBatchBuilder_${nonce}_${multisig_address}"
    previous_batches=()
    for existing_file in "${batch_prefix}"_*.json; do
        index_part=${existing_file#"${batch_prefix}_"}
        [[ "$index_part" =~ ^[0-9]+\.json$ ]] || continue
        if [ "$(jq -r '.meta.name' "$existing_file" 2>/dev/null)" == "$batch_name" ]; then
            previous_batches+=("$existing_file")
        fi
    done
    if [ ${#previous_batches[@]} -gt 1 ]; then
        echo "Error: several batches for $key at nonce $nonce (${previous_batches[*]}); remove the outdated ones"
        echo "Skipping $key"
        echo ""
        continue
    fi
    stale_batch=${previous_batches[0]:-}

    desired_threshold=$(jq -r ".threshold" "$config_dir_path/${key}.json")
    IFS=$'\n' read -d '' -r -a desired_signers < <(jq -r '.signers[]' "$config_dir_path/${key}.json")
    json='{"chainId":"'$chain_id'","createdAt":'$(date +%s)',"meta":{"name":"'"$batch_name"'","createdFromSafeAddress":"'"$multisig_address"'"},"transactions":[]}'

    echo "Processing $key multisig at address: $multisig_address"
    current_threshold=$(cast call $multisig_address "getThreshold()(uint256)" --rpc-url $DEPLOYMENT_RPC_URL)
    current_signers=$(cast call $multisig_address "getOwners()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
    if ! [[ "$desired_threshold" =~ ^[0-9]+$ && "$current_threshold" =~ ^[0-9]+$ ]]; then
        echo "Error: could not read the thresholds for $key (desired: '$desired_threshold', current: '$current_threshold')"
        echo "Skipping $key"
        echo ""
        continue
    fi
    
    # Parse current signers into array
    IFS=$'\n' read -d '' -r -a current_signers_array < <(echo "$current_signers" | grep -o "0x[a-fA-F0-9]\{40\}")
    current_signers_count=${#current_signers_array[@]}
    
    echo "Current state: $current_signers_count owners, threshold: $current_threshold"
    echo "Desired state: ${#desired_signers[@]} owners, threshold: $desired_threshold"
    
    # Resolve any non-address signers (multisig keys) to actual addresses
    unresolved_signers=()
    for i in "${!desired_signers[@]}"; do
        signer="${desired_signers[$i]}"
        if ! is_address "$signer"; then
            resolved_signer=$(get_multisig_address "$signer")
            if ! is_address "$resolved_signer"; then
                unresolved_signers+=("$signer")
            fi
            desired_signers[$i]=$resolved_signer
        fi
    done
    if [ ${#unresolved_signers[@]} -gt 0 ]; then
        echo "Error: signer(s) ${unresolved_signers[*]} are neither addresses nor multisig keys on this chain"
        echo "Skipping $key"
        echo ""
        continue
    fi
    
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
            append_safe_call "addOwnerWithThreshold(address,uint256)" "$desired_signer" "$current_threshold"
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
        
        # Calculate final owner count after all operations
        final_owner_count=${#desired_signers[@]}
        
        # Determine the threshold to use during removals
        # If final owner count < current threshold, we need to reduce threshold first
        if [ "$final_owner_count" -lt "$current_threshold" ]; then
            if [ "$desired_threshold" -gt "$final_owner_count" ]; then
                echo "Error: Desired threshold ($desired_threshold) exceeds final owner count ($final_owner_count)"
                echo "Skipping $key"
                echo ""
                continue
            fi
            # Reduce threshold before removing owners
            echo "Reducing threshold to $desired_threshold before removing owners"
            append_safe_call "changeThreshold(uint256)" "$desired_threshold"
            removal_threshold=$desired_threshold
            threshold_already_changed=true
        else
            removal_threshold=$current_threshold
            threshold_already_changed=false
        fi
        
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
            append_safe_call "removeOwner(address,address,uint256)" "$prev_owner" "$owner_to_remove" "$removal_threshold"
            
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
        threshold_already_changed=false
    fi
    
    # Phase 3: Adjust threshold if needed (skip if already changed in Phase 2)
    if [ "$current_threshold" -ne "$desired_threshold" ] && [ "$threshold_already_changed" != "true" ]; then
        echo "Setting threshold to $desired_threshold"
        append_safe_call "changeThreshold(uint256)" "$desired_threshold"
    fi
    
    # Save the transaction batch if there are any transactions
    transaction_count=$(echo $json | jq '.transactions | length')
    if [ "$transaction_count" -gt 0 ]; then
        echo "Generated $transaction_count operations for $key multisig"
        if [ -n "$stale_batch" ]; then
            output_file=$stale_batch
            stale_batch=""
        else
            output_file="${batch_prefix}_$(script/utils/getFileNameCounter.sh "${batch_prefix}.json").json"
        fi
        echo "$json" | jq '.' > "$output_file"
        echo "Saved to $output_file"
        if [ "$nonce" == "0" ]; then
            echo "MergeSafeBatchBuilderFiles cannot target nonce 0: load this file in the Safe UI directly"
        elif [ -z "$safe_nonce" ]; then
            echo "Named with the on-chain nonce. If $key has queued transactions, re-run with --safe-address $key"
            echo "--safe-nonce <the nonce of the other batches> so MergeSafeBatchBuilderFiles picks it up"
        fi
    else
        echo "No operations needed for $key multisig (already in desired state)"
    fi
    echo ""
done

drop_stale_batch
