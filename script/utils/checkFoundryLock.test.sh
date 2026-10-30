#!/bin/bash

# Regression tests for checkFoundryLock.sh against throwaway repositories with one submodule (lib/dep) whose commits
# go A -> B -> C. Run from anywhere: script/utils/checkFoundryLock.test.sh

set -euo pipefail

check=$(cd "$(dirname "$0")" && pwd)/checkFoundryLock.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always

git init -q "$work/dep"
for name in A B C; do
    git -C "$work/dep" commit -q --allow-empty -m "$name"
    eval "$name=$(git -C "$work/dep" rev-parse HEAD)"
done

failures=0
output=""

# A repository recording lib/dep at $1 with foundry.lock pinning $2.
setup() {
    rm -rf "$work/repo"
    git init -q "$work/repo"
    cd "$work/repo"
    git submodule add -q "$work/dep" lib/dep
    git -C lib/dep checkout -q "$1"
    git add lib/dep
    printf '{\n  "lib/dep": {\n    "rev": "%s"\n  }\n}' "$2" > foundry.lock
    git add foundry.lock
    git commit -q -m setup
}

run() {
    local rc=0
    output=$("$check" "$@" 2>&1) || rc=$?
    return $rc
}

locked() {
    jq -r '.["lib/dep"].rev' foundry.lock
}

expect() {
    local name=$1 condition=$2
    if eval "$condition"; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        echo "$output" | sed 's/^/     /'
        failures=$((failures + 1))
    fi
}

setup "$A" "$A"
expect "in sync passes" 'run'

setup "$B" "$A"
expect "a lock behind the recorded commit fails" '! run && [[ $output == *"pins lib/dep at $A"* ]]'

setup "$A" "$A"
git -C lib/dep checkout -q "$B"
git add lib/dep
expect "a staged bump fails until fixed" '! run'
expect "--fix takes the staged bump" 'run --fix && [ "$(locked)" == "$B" ]'
git add foundry.lock
git commit -q -m bump
expect "the fixed bump passes once committed" 'run'

setup "$A" "$A"
git -C lib/dep checkout -q "$B"
expect "an unstaged bump fails until fixed" '! run'
expect "--fix takes the unstaged bump and says it is not staged" \
    'run --fix && [ "$(locked)" == "$B" ] && [[ $output == *"not staged"* ]]'
git add lib/dep foundry.lock
git commit -q -m bump
expect "the fixed unstaged bump passes once committed" 'run'

setup "$A" "$A"
git -C lib/dep checkout -q "$B"
jq --arg rev "$B" '.["lib/dep"].rev = $rev' foundry.lock > lock.tmp && mv lock.tmp foundry.lock
expect "--fix keeps a lock already at the pending bump" 'run --fix && [ "$(locked)" == "$B" ]'

setup "$C" "$A"
git -C lib/dep checkout -q "$A"
expect "a checkout rolled back behind the recorded commit is reported" \
    '! run && [[ $output == *"older than the recorded"* ]]'
expect "--fix does not take a rolled-back checkout" '! run --fix && [ "$(locked)" == "$A" ]'

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed."
    exit 1
fi
echo "All checks passed."
