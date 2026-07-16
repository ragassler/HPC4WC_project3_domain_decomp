#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 PXxPY" >&2
    echo "Example: $0 2x2" >&2
    echo "Optional environment: BASE_INTERIOR=400, THREADS=8, NT=200, MPIEXEC=~/.julia/bin/mpiexecjl" >&2
}

gcd() {
    local a=$1 b=$2 remainder
    while (( b != 0 )); do
        remainder=$((a % b))
        a=$b
        b=$remainder
    done
    echo "$a"
}

[[ $# -eq 1 ]] || { usage; exit 2; }
[[ $1 =~ ^([1-9][0-9]*)[xX]([1-9][0-9]*)$ ]] || { usage; exit 2; }

px=${BASH_REMATCH[1]}
py=${BASH_REMATCH[2]}
topology="${px}x${py}"
nprocs=$((px * py))
threads=${THREADS:-8}
nt=${NT:-200}
base_interior=${BASE_INTERIOR:-400}
mpiexec=${MPIEXEC:-"$HOME/.julia/bin/mpiexecjl"}

[[ $threads =~ ^[1-9][0-9]*$ ]] || { echo "THREADS must be a positive integer." >&2; exit 2; }
[[ $base_interior =~ ^[1-9][0-9]*$ ]] || { echo "BASE_INTERIOR must be a positive integer." >&2; exit 2; }
[[ -x $mpiexec ]] || { echo "MPI launcher is not executable: $mpiexec" >&2; exit 2; }

topology_lcm=$((px / $(gcd "$px" "$py") * py))
unit=$(( (base_interior + topology_lcm - 1) / topology_lcm * topology_lcm ))

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${OUTPUT_DIR:-"$repo_root/out/manual_aspect_ratios"}
mkdir -p "$output_dir"

for ratio_y in 8 4 2 1; do
    nx=$((unit + 2))
    ny=$((unit * ratio_y + 2))
    ratio="1x${ratio_y}"
    output="$output_dir/topology_${topology}_ratio_${ratio}_threads_${threads}.log"
    echo "Running topology=$topology ranks=$nprocs threads=$threads ratio=1:$ratio_y grid=${nx}x${ny}"
    "$mpiexec" -n "$nprocs" julia -t "$threads" --project="$repo_root" \
        "$repo_root/src/manual.jl" --topology "$topology" \
        --nx "$nx" --ny "$ny" --nt "$nt" --benchmark 2>&1 | tee "$output"
done
