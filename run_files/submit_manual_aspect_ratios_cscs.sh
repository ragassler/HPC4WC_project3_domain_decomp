#!/usr/bin/env bash
#SBATCH --account=julia-gpu-course2026-ethz
#SBATCH --job-name=manual_aspects
#SBATCH --output=out/manual_aspects_cscs.%j.out
#SBATCH --error=out/manual_aspects_cscs.%j.err
#SBATCH --time=01:00:00

set -euo pipefail

usage() {
    echo "Usage: $0 PXxPY" >&2
    echo "This script submits itself; run: $0 2x2" >&2
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

threads=${THREADS:-8}
nt=${NT:-200}
base_interior=${BASE_INTERIOR:-400}
topology_lcm=$((px / $(gcd "$px" "$py") * py))
unit=$(( (base_interior + topology_lcm - 1) / topology_lcm * topology_lcm ))
output_dir=${OUTPUT_DIR:-"$repo_root/out/manual_aspect_ratios_cscs"}
mkdir -p "$output_dir"

for ratio_y in 8 4 2 1; do
    nx=$((unit + 2))
    ny=$((unit * ratio_y + 2))
    ratio="1x${ratio_y}"
    output="$output_dir/topology_${topology}_ratio_${ratio}_threads_${threads}_job_${SLURM_JOB_ID}.log"
    echo "Running CSCS GPU topology=$topology ranks=$nprocs threads=$threads ratio=1:$ratio_y grid=${nx}x${ny}"
    srun --uenv julia/25.5:v1 --view=juliaup --ntasks="$nprocs" \
        julia -t "$threads" --project="$repo_root" "$repo_root/src/manual.jl" \
        --topology "$topology" --nx "$nx" --ny "$ny" --nt "$nt" --benchmark \
        2>&1 | tee "$output"
done
