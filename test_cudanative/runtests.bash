#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

PATTERN='(jl_value|jl_box|alloca|gcframe)'

function checkscript {
    local SCRIPT
    local OUTPUT

    SCRIPT="$1"

    echo "[+] Testing $SCRIPT ..."
    OUTPUT="$(julia --depwarn=no "$SCRIPT" 2>&1)"
    [[ $? -eq 0 ]] || (echo "$OUTPUT" && exit 1)

    echo "$OUTPUT" \
        | egrep --invert '^;'               \
        | egrep --invert '^define.*@julia'  \
        | egrep "$PATTERN"
    if [ "$?" -eq 0 ]; then
        echo "[-] contains runtime calls"
        return 1
    else
        echo "[+] ok"
        return 0
    fi
}

for SCRIPT in fail*.jl; do
    checkscript "$SCRIPT" || exit 1
done
