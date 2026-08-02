#!/bin/bash -l
#SBATCH --account=hpc4wc-course2026-ethz
#SBATCH --job-name="strong_scaling"
#SBATCH --output=out/strong_scaling.%j.o
#SBATCH --error=out/strong_scaling.%j.e
#SBATCH --time=02:00:00
#SBATCH --nodes=4
#SBATCH --ntasks=16
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1

export MPICH_GPU_SUPPORT_ENABLED=1
export IGG_CUDAAWARE_MPI=1
export JULIA_CUDA_USE_COMPAT=false

# Strong-scaling sizes with a 4:1 global aspect ratio.
# Nx/Ny values include the +2 halo padding (e.g. 2048+2 x 512+2 = 2050 x 514).
sizes=(
    "262146,65538"
    "524290,131074"
    "1048578,262146"
)

topologies=(
    "(16,1)"
    "(8,2)"
    "(4,4)"
    "(2,8)"
    "(1,16)"
)

manual_bench="docs/benchmark/strong_scaling_manual.csv"
baseline_bench="docs/benchmark/strong_scaling_baseline.csv"
manual_outdir_root="docs/frames/strong_scaling/manual"
baseline_outdir_root="docs/frames/strong_scaling/baseline"

mkdir -p "$(dirname "$manual_bench")" "$manual_outdir_root" "$baseline_outdir_root"

for size in "${sizes[@]}"; do
    IFS=',' read -r nx ny <<< "$size"
    for topo in "${topologies[@]}"; do
        topo_clean=$(echo "${topo}" | tr -d '(),')
        outdir="${manual_outdir_root}/nx_${nx}_ny_${ny}/topo_${topo_clean}"
        mkdir -p "${outdir}"

        srun --export=ALL,USE_GPU=true --uenv julia/25.5:v1 --view=juliaup julia --project /users/course_00407/project/manual.jl \
            --topo "${topo}" \
            --nx "${nx}" \
            --ny "${ny}" \
            --nt 20 \
            --warmup 5 \
            --runs 1 \
            --benchmark \
            --benchdir "${manual_bench}" \
            --outdir "${outdir}"
    done

    # Baseline run with IGG automatic process topology and domain decomposition.
    srun --export=ALL,USE_GPU=true --uenv julia/25.5:v1 --view=juliaup julia --project /users/course_00407/project/baseline.jl \
        --nx "${nx}" \
        --ny "${ny}" \
        --nt 20 \
        --warmup 5 \
        --benchmark \
        --benchdir "${baseline_bench}" \
        --outdir "${baseline_outdir_root}/nx_${nx}_ny_${ny}"

done
