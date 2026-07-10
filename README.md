# HPC4WC Project 3: Domain Decomposition SWE

Small 2D shallow-water-equation solver using `ParallelStencil`, MPI, and
`ImplicitGlobalGrid` for domain decomposition.

## Baseline Provenance

The baseline solver in `src/baseline.jl` is adapted from the multi-XPU solver
`src/xpu/2d_swe_multi_xpu_wb.jl` of
[S1ntax3rror/ShallowWater4PDEonGPU](https://github.com/S1ntax3rror/ShallowWater4PDEonGPU).
Domain decomposition uses
[ImplicitGlobalGrid.jl](https://github.com/eth-cscs/ImplicitGlobalGrid.jl).

## Setup

Install the Julia environment once:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

The main solver is:

```text
src/baseline.jl
```

## Run Locally

The current code fixes the MPI topology to `2 x 2`, so run with 4 ranks:

```bash
mpiexec -n 4 julia --project src/baseline.jl
```

If the system `mpiexec` does not match `MPI.jl`, use the launcher selected by
the Julia environment:

```bash
julia --project -e 'using MPI; run(`$(MPI.mpiexec()) -n 4 julia --project src/baseline.jl`)'
```

Optional global grid arguments:

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 500 --ny 500
```

Quick verification run with serialized visualization arrays:

```bash
julia --project -e 'using MPI; run(`$(MPI.mpiexec()) -n 4 julia --project src/baseline.jl --nx 80 --ny 80 --nt 20 --viz --outdir docs/frames/simple_ic`)'
julia --project scripts/visualize_arrays.jl --input docs/frames/simple_ic --output docs/frames/simple_ic/plots
```

The script currently calls `swe2d_topography_frames(...; nt=2000, do_viz=false)`,
so it runs a benchmark-style simulation and does not write frames by default.

## Run With Slurm

Submit the provided 4-rank job:

```bash
mkdir -p out
sbatch run_files/run_2D_swe_multi_xpu_wb.sh
```

There is also a weak-scaling helper:

```bash
bash run_files/weak_scaling.sh
```

Note: the current solver source fixes `dims_mpi = [2, 2]`, so only 4-task
runs work without changing the topology in `src/baseline.jl`.

The Slurm scripts use CSCS-style Julia uenv commands and set:

```bash
MPICH_GPU_SUPPORT_ENABLED=1
IGG_CUDAAWARE_MPI=1
JULIA_CUDA_USE_COMPAT=false
```

Adjust the account, uenv, number of tasks, and topology if running on a
different cluster.

## Domain Decomposition Baseline

`ImplicitGlobalGrid` creates a Cartesian MPI grid from local array sizes. In
this code:

```julia
dims_mpi = [2, 2]
nx = round(Int, (nx_global - 2) / dims_mpi[1]) + 2
ny = round(Int, (ny_global - 2) / dims_mpi[2]) + 2

me, dims, nprocs, coords, comm_cart = init_global_grid(
    nx, ny, 1;
    dimx=dims_mpi[1], dimy=dims_mpi[2], dimz=1,
    init_MPI=false,
    select_device=false,
)
```

Each rank owns one local block with halo cells. The global size is recovered
with `nx_g()` and `ny_g()`, global coordinates use `x_g(...)` and `y_g(...)`,
and halo exchange is done with `update_halo!(...)`. Boundary conditions are
only applied on ranks whose `coords` touch the outer global boundary.

## References

1. [S1ntax3rror/ShallowWater4PDEonGPU](https://github.com/S1ntax3rror/ShallowWater4PDEonGPU)
2. [eth-cscs/ImplicitGlobalGrid.jl](https://github.com/eth-cscs/ImplicitGlobalGrid.jl)

TODO:
- look that it works on cpu and gpu somehow
- benchmark suite,
- decomposition of domain plotting

