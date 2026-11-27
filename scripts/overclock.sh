#!/bin/bash
# Usage: ./overclock.sh CPU_MULT MEM_MULT      e.g. ./overclock.sh 40 28
#   Multipliers are decimal PLL feedback multipliers (1..127), not frequencies.
#   Override the directory with SDIMG_DIR=/path ./overclock.sh ...

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 CPU_MULT MEM_MULT   (decimal, 1..127; example: $0 40 28)" >&2
    exit 1
fi

SDIMG_DIR="$PWD"
BASE_BIN="${SDIMG_DIR}/BOOT.bin"
OFFSETS_FILE="${SDIMG_DIR}/.offsets"
OC_DIR="${SDIMG_DIR}/overclocks"

declare -A MULT
for pair in "CPU:$1" "MEM:$2"; do
    name="${pair%%:*}"; val="${pair#*:}"
    if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$((10#$val))" -lt 1 ] || [ "$((10#$val))" -gt 127 ]; then
        echo "Error: $name multiplier '$val' is invalid. Must be an integer >0 and <128." >&2
        exit 3
    fi
    MULT[$name]=$((10#$val))
done

[ -f "$BASE_BIN" ]     || { echo "Error: $BASE_BIN not found" >&2; exit 2; }
[ -f "$OFFSETS_FILE" ] || { echo "Error: $OFFSETS_FILE not found" >&2; exit 2; }

declare -A OFF
while IFS='=' read -r key val; do
    OFF[$key]=$((val))
done < <(grep -E '^(CPU|MEM)_[123]=0x[0-9A-Fa-f]+$' "$OFFSETS_FILE")

size=$(stat -c %s "$BASE_BIN")
for key in CPU_1 CPU_2 CPU_3 MEM_1 MEM_2 MEM_3; do
    if [ -z "${OFF[$key]:-}" ]; then
        echo "Error: $key missing/malformed in $OFFSETS_FILE" >&2
        exit 4
    fi
    if [ $((OFF[$key] + 4)) -gt "$size" ]; then
        echo "Error: $key offset $(printf '0x%X' "${OFF[$key]}") is outside $BASE_BIN ($size bytes)" >&2
        exit 4
    fi
done

mkdir -p "$OC_DIR"
OUT="${OC_DIR}/FSBL_${MULT[CPU]}_${MULT[MEM]}"
cp -f "$BASE_BIN" "$OUT"

patch_word() {   
    local v=$3
    printf "$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' \
        $((v & 0xFF)) $(((v >> 8) & 0xFF)) $(((v >> 16) & 0xFF)) $(((v >> 24) & 0xFF)))" |
        dd of="$1" bs=1 seek="$2" conv=notrunc status=none
}

read_word() {
    od -An -tu4 -j "$2" -N 4 --endian=little "$1" | tr -d ' '
}

for name in CPU MEM; do
    want=$((MULT[$name] << 12))
    for n in 1 2 3; do
        off=${OFF[${name}_${n}]}
        patch_word "$OUT" "$off" "$want"
        got=$(read_word "$OUT" "$off")
        if [ "$got" -ne "$want" ]; then
            echo "Error: verify failed at $(printf '0x%08X' "$off") ($name[$n])" >&2
            rm -f "$OUT"
            exit 5
        fi
        printf '  %s[%d] @ 0x%08X: set multiplier %d\n' "$name" "$n" "$off" "${MULT[$name]}"
    done
done

echo "Done: $OUT"