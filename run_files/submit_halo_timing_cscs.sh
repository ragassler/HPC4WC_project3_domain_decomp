#!/usr/bin/env bash
#SBATCH --account=julia-gpu-course2026-ethz
#SBATCH --job-name=halo_timing
#SBATCH --output=out/halo_timing.%j.out
#SBATCH --error=out/halo_timing.%j.err
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

# ==============================================================================
# PARAMETER-EINSTELLUNGEN
# ==============================================================================
nx=${NX:-802}
ny=${NY:-402}
nt=${NT:-200}
warmup=${WARMUP:-5}
output_dir=${OUTPUT_DIR:-"$repo_root/out/halo_timing_cscs"}
benchdir=${BENCHDIR:-"$repo_root/docs/benchmark/halo_exchange.csv"}

mkdir -p "$output_dir" "$(dirname "$benchdir")"

(( (nx - 2) % px == 0 )) || { echo "NX-2 must be divisible by PX ($px)." >&2; exit 2; }
(( (ny - 2) % py == 0 )) || { echo "NY-2 must be divisible by PY ($py)." >&2; exit 2; }

output="$output_dir/topology_${topology}_job_${SLURM_JOB_ID}.log"

echo "============================================"
echo " Running halo-timing benchmark"
echo " Topology:  ${topology} (${nprocs} ranks)"
echo " Grid:      ${nx}x${ny}"
echo " Steps:     ${nt}"
echo " Runs:      ${runs}"
echo " Warmup:    ${warmup}"
echo " Output:    ${benchdir}"
echo "============================================"

srun --uenv julia/25.5:v1 --view=juliaup --ntasks="$nprocs" \
    julia --project="$repo_root" "$repo_root/src/AI_manual_time_halo.jl" \
    --topology "$topology" \
    --nx "$nx" --ny "$ny" --nt "$nt" \
    --warmup "$warmup" \
    --benchmark --benchdir "$benchdir" \
    2>&1 | tee "$output"

echo "Halo-timing benchmark finished."