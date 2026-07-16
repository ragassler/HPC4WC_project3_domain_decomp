#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 PXxPY" >&2
    echo "Example: $0 2x2" >&2
    echo "Optional environment: THREAD_COUNTS='1 2 4 8', NX=2002, NY=2002, NT=200, MPIEXEC=~/.julia/bin/mpiexecjl" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }
[[ $1 =~ ^([1-9][0-9]*)[xX]([1-9][0-9]*)$ ]] || { usage; exit 2; }

px=${BASH_REMATCH[1]}
py=${BASH_REMATCH[2]}
topology="${px}x${py}"
nprocs=$((px * py))

thread_counts=${THREAD_COUNTS:-"1 2 4 8"}
nx=${NX:-2002}
ny=${NY:-2002}
nt=${NT:-200}
mpiexec=${MPIEXEC:-"$HOME/.julia/bin/mpiexecjl"}

(( (nx - 2) % px == 0 )) || { echo "NX-2 must be divisible by PX ($px)." >&2; exit 2; }
(( (ny - 2) % py == 0 )) || { echo "NY-2 must be divisible by PY ($py)." >&2; exit 2; }
[[ -x $mpiexec ]] || { echo "MPI launcher is not executable: $mpiexec" >&2; exit 2; }

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${OUTPUT_DIR:-"$repo_root/out/manual_threads"}
mkdir -p "$output_dir"

for threads in $thread_counts; do
    [[ $threads =~ ^[1-9][0-9]*$ ]] || { echo "Invalid thread count: $threads" >&2; exit 2; }
    output="$output_dir/topology_${topology}_threads_${threads}.log"
    echo "Running topology=$topology ranks=$nprocs threads=$threads grid=${nx}x${ny}"
    "$mpiexec" -n "$nprocs" julia -t "$threads" --project="$repo_root" \
        "$repo_root/src/manual.jl" --topology "$topology" \
        --nx "$nx" --ny "$ny" --nt "$nt" --benchmark 2>&1 | tee "$output"
done
