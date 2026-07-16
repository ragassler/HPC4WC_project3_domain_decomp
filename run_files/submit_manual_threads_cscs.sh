#!/usr/bin/env bash
#SBATCH --account=julia-gpu-course2026-ethz
#SBATCH --job-name=manual_threads
#SBATCH --output=out/manual_threads_cscs.%j.out
#SBATCH --error=out/manual_threads_cscs.%j.err
#SBATCH --time=00:30:00

set -euo pipefail

usage() {
    echo "Usage: $0 PXxPY" >&2
    echo "This script submits itself; run: $0 2x2" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }
[[ $1 =~ ^([1-9][0-9]*)[xX]([1-9][0-9]*)$ ]] || { usage; exit 2; }

px=${BASH_REMATCH[1]}
py=${BASH_REMATCH[2]}
topology="${px}x${py}"
nprocs=$((px * py))
gpus_per_node=${GPUS_PER_NODE:-4}
nodes=$(( (nprocs + gpus_per_node - 1) / gpus_per_node ))

repo_root=${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
mkdir -p "$repo_root/out"

if [[ -z ${SLURM_JOB_ID:-} ]]; then
    exec sbatch --nodes="$nodes" --ntasks="$nprocs" \
        --ntasks-per-node="$gpus_per_node" --gpus-per-task=1 \
        --chdir="$repo_root" --export="ALL,REPO_ROOT=$repo_root" "$0" "$topology"
fi

export MPICH_GPU_SUPPORT_ENABLED=1
export IGG_CUDAAWARE_MPI=1
export JULIA_CUDA_USE_COMPAT=false
export USE_GPU=true

thread_counts=${THREAD_COUNTS:-"1 2 4 8"}
nx=${NX:-802}
ny=${NY:-402}
nt=${NT:-200}
output_dir=${OUTPUT_DIR:-"$repo_root/out/manual_threads_cscs"}
mkdir -p "$output_dir"

(( (nx - 2) % px == 0 )) || { echo "NX-2 must be divisible by PX ($px)." >&2; exit 2; }
(( (ny - 2) % py == 0 )) || { echo "NY-2 must be divisible by PY ($py)." >&2; exit 2; }

for threads in $thread_counts; do
    output="$output_dir/topology_${topology}_threads_${threads}_job_${SLURM_JOB_ID}.log"
    echo "Running CSCS GPU topology=$topology ranks=$nprocs threads=$threads grid=${nx}x${ny}"
    srun --uenv julia/25.5:v1 --view=juliaup --ntasks="$nprocs" \
        julia -t "$threads" --project="$repo_root" "$repo_root/src/manual.jl" \
        --topology "$topology" --nx "$nx" --ny "$ny" --nt "$nt" --benchmark \
        2>&1 | tee "$output"
done
