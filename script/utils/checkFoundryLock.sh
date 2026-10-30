#!/bin/bash

# forge install checks out the revisions pinned in foundry.lock, not the submodule commits, so a lock left behind by a
# submodule bump silently rolls dependencies back. Fails when the two disagree; --fix rewrites the lock to match.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    exit 1
fi

lock=foundry.lock
submodules=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | LC_ALL=C sort)
locked=$(jq -r 'keys[]' "$lock" | LC_ALL=C sort)

gitlink() {
    git ls-tree HEAD "$1" | awk '{print $3}'
}

if [ "${1:-}" == "--fix" ]; then
    args=()
    for path in $(LC_ALL=C comm -12 <(echo "$submodules") <(echo "$locked")); do
        args+=(--arg "$path" "$(gitlink "$path")")
    done
    fixed=$(jq --indent 2 'reduce ($ARGS.named | keys[]) as $k (.; .[$k] |= (
        if has("tag") then .tag.rev = $ARGS.named[$k]
        elif has("branch") then .branch.rev = $ARGS.named[$k]
        else .rev = $ARGS.named[$k] end
    ))' "${args[@]}" "$lock")
    printf '%s' "$fixed" > "$lock"
    echo "foundry.lock revisions set to the submodule commits."
fi

status=0

for path in $(LC_ALL=C comm -23 <(echo "$submodules") <(echo "$locked")); do
    echo "Error: $path is a submodule but has no entry in foundry.lock."
    status=1
done

for path in $(LC_ALL=C comm -13 <(echo "$submodules") <(echo "$locked")); do
    echo "Error: $path is in foundry.lock but is not a submodule."
    status=1
done

for path in $(LC_ALL=C comm -12 <(echo "$submodules") <(echo "$locked")); do
    expected=$(gitlink "$path")
    rev=$(jq -r --arg p "$path" '.[$p] | .rev // .tag.rev // .branch.rev // empty' "$lock")
    if [ "$rev" != "$expected" ]; then
        echo "Error: foundry.lock pins $path at ${rev:-nothing}, but the submodule points to $expected."
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    echo "Add or remove the listed entries, run script/utils/checkFoundryLock.sh --fix for the revisions," \
        "and commit foundry.lock together with the submodule change."
else
    echo "foundry.lock matches the submodule commits."
fi

exit $status
