#!/bin/bash

# forge install checks out the revisions pinned in foundry.lock, not the submodule commits, so a lock left behind by a
# submodule bump silently rolls dependencies back. Fails when the two disagree; --fix rewrites the lock to match.
#
# A submodule's revision is its checkout when that differs from the recorded commit and is not older (a pending bump,
# staged or not), otherwise the recorded commit. A checkout older than the recorded commit is what forge install leaves
# behind with a stale lock, so it is reported instead of being taken as a bump.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    exit 1
fi

lock=foundry.lock
submodules=$(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | LC_ALL=C sort)
locked=$(jq -r 'keys[]' "$lock" | LC_ALL=C sort)
both=$(LC_ALL=C comm -12 <(echo "$submodules") <(echo "$locked"))

# The commit git will record for the submodule: the index entry, which includes a staged bump.
recorded_revision() {
    git ls-files -s -- "$1" | awk '$1 == "160000" {print $2}'
}

# The revision foundry.lock should pin, or a reason on stderr when the checkout can't be trusted.
pending_revision() {
    local path=$1 recorded checkout rc=0
    recorded=$(recorded_revision "$path")
    if [ ! -e "$path/.git" ]; then
        echo "$recorded"
        return 0
    fi
    checkout=$(git -C "$path" rev-parse HEAD)
    if [ "$checkout" == "$recorded" ]; then
        echo "$recorded"
        return 0
    fi
    git -C "$path" merge-base --is-ancestor "$checkout" "$recorded" 2> /dev/null || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "Error: $path is checked out at $checkout, older than the recorded $recorded (forge install with a stale" \
            "lock?). Run git submodule update --init --recursive, or stage the submodule if the downgrade is intended." >&2
        return 1
    fi
    if [ "$rc" -ne 1 ]; then
        echo "Error: can't tell whether $path checkout $checkout is newer than the recorded $recorded." \
            "Run git submodule update --init --recursive and retry." >&2
        return 1
    fi
    echo "$checkout"
}

status=0

if [ "${1:-}" == "--fix" ]; then
    args=()
    for path in $both; do
        if revision=$(pending_revision "$path" 2> /dev/null); then
            args+=(--arg "$path" "$revision")
        fi
    done
    fixed=$(jq --indent 2 'reduce ($ARGS.named | keys[]) as $k (.; .[$k] |= (
        if has("tag") then .tag.rev = $ARGS.named[$k]
        elif has("branch") then .branch.rev = $ARGS.named[$k]
        else .rev = $ARGS.named[$k] end
    ))' ${args[@]+"${args[@]}"} "$lock")
    printf '%s' "$fixed" > "$lock"
    echo "foundry.lock revisions set to the submodule commits."
fi

for path in $(LC_ALL=C comm -23 <(echo "$submodules") <(echo "$locked")); do
    echo "Error: $path is a submodule but has no entry in foundry.lock."
    status=1
done

for path in $(LC_ALL=C comm -13 <(echo "$submodules") <(echo "$locked")); do
    echo "Error: $path is in foundry.lock but is not a submodule."
    status=1
done

for path in $both; do
    if ! expected=$(pending_revision "$path"); then
        status=1
        continue
    fi
    rev=$(jq -r --arg p "$path" '.[$p] | .rev // .tag.rev // .branch.rev // empty' "$lock")
    if [ "$rev" != "$expected" ]; then
        echo "Error: foundry.lock pins $path at ${rev:-nothing}, but the submodule is at $expected."
        status=1
    fi
    if [ "$expected" != "$(recorded_revision "$path")" ]; then
        echo "Note: $path is checked out at $expected but the submodule change is not staged; commit it together with" \
            "foundry.lock."
    fi
done

if [ "$status" -ne 0 ]; then
    echo "Add or remove the listed entries, run script/utils/checkFoundryLock.sh --fix for the revisions," \
        "and commit foundry.lock together with the submodule change."
else
    echo "foundry.lock matches the submodule commits."
fi

exit $status
