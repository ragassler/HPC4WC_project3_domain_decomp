# HPC4WC Project 3: Domain Decomposition SWE

Small 2D shallow-water-equation solver used to study domain decomposition and
MPI halo exchange. The project currently contains two main solver variants:

- `src/baseline.jl`: baseline implementation using `ImplicitGlobalGrid.jl`.
- `src/manual.jl`: manual MPI Cartesian-domain-decomposition version without
  `ImplicitGlobalGrid.jl`.

Both versions use `ParallelStencil` kernels and currently run on the CPU
backend (`Threads`). `USE_GPU` is set to `false` in the solver files.

## Provenance

The numerical solver is adapted from the SWE project reference implementation
`src/xpu/2d_swe_multi_xpu_wb.jl` in
[S1ntax3rror/ShallowWater4PDEonGPU](https://github.com/S1ntax3rror/ShallowWater4PDEonGPU).

This repository has been simplified for the HPC4WC domain-decomposition project:

- Uses one simple Gaussian free-surface perturbation as initial condition.
- Uses flat bathymetry (`z = 0`) only.
- Removes topography loading and related data preprocessing.
- Removes the expansion-factor/topography experiment code.
- Removes GPU memory-workaround/test code from the reference solver.
- Keeps array-output visualization instead of plotting from inside the solver.
- Adds benchmark mode that times only the main simulation loop.
- Adds saved domain-decomposition metadata for external plotting.
- Keeps communication simple: there is currently **no hidden/overlapped
  communication**. The manual version uses blocking halo exchange. Overlap can
  be added later as a separate optimization.

## Setup

Instantiate the Julia environment once:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

If the system `mpiexec` does not match the MPI used by `MPI.jl`, use:

```bash
julia --project -e 'using MPI; println(MPI.mpiexec())'
```

and launch through `MPI.mpiexec()` as shown below.

## Solver Options

Both `src/baseline.jl` and `src/manual.jl` accept the same command-line options:

```text
--nx N          Global x size including outer halos/default boundary cells
--ny N          Global y size including outer halos/default boundary cells
--nt N          Number of timesteps
--outdir DIR    Directory for saved arrays and domain-decomposition metadata
--viz           Save serialized field arrays for later plotting
--benchmark     Run timing mode: no saved arrays, no progress output
--topology PxQ  Manual solver only: MPI Cartesian topology (default 2x2)
--warmup N      Manual benchmark warm-up iterations excluded from timing (default 5)
```

Current script defaults:

```text
baseline.jl: --nx 802 --ny 802 --nt 200 --outdir docs/frames/baseline
manual.jl:   --nx 802 --ny 402 --nt 200 --outdir docs/frames/baseline
```

`baseline.jl` lets `ImplicitGlobalGrid.jl`/MPI choose a compact Cartesian
topology from the number of MPI ranks. `manual.jl` accepts its topology with
`--topology PXxPY` and must use `PX * PY` MPI ranks. In both cases, the global
interior size `nx - 2` by `ny - 2` must be divisible by the chosen topology.

## Run Baseline

`baseline.jl` uses `ImplicitGlobalGrid.jl` for the Cartesian decomposition,
global indices, and halo updates. The topology is selected automatically from
the number of MPI ranks.

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 100 --ny 400 --nt 20
```

Equivalent launch using the MPI selected by the Julia environment:

```bash
julia --project -e 'using MPI; run(`$(MPI.mpiexec()) -n 4 julia --project src/baseline.jl --nx 100 --ny 400 --nt 20`)'
```

Benchmark mode:

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 500 --ny 500 --nt 100 --benchmark
```

Benchmark output is a single line from rank 0:

```text
BENCHMARK walltime_seconds=... nt=... global_size=... local_size=... nprocs=... steps_per_second=... cell_updates_per_second=...
```

## Run Manual MPI Version

`manual.jl` removes `ImplicitGlobalGrid.jl` and implements the Cartesian
communicator, global indexing, gather, and halo exchange manually with `MPI.jl`.

```bash
mpiexec -n 4 julia --project src/manual.jl --topology 2x2 --nx 102 --ny 402 --nt 20
```

Benchmark mode:

```bash
mpiexec -n 4 julia --project src/manual.jl --nx 500 --ny 500 --nt 100 --benchmark
```

Current limitations of `manual.jl`:

- Uniform local block sizes only.
- Blocking halo exchange only; no hidden communication yet.
- CPU backend by default; set `USE_GPU=true` to select the CUDA backend.

## Save And Plot Field Arrays

Use `--viz` to save serialized arrays in `--outdir`. The solver writes files
named `array_frame_*.jls`. Plot them afterwards with:

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 80 --ny 80 --nt 20 --viz --outdir docs/frames/baseline
julia --project scripts/visualize_arrays.jl --input docs/frames/baseline --output docs/frames/baseline/plots
```

The same workflow works for `src/manual.jl`:

```bash
mpiexec -n 4 julia --project src/manual.jl --nx 80 --ny 80 --nt 20 --viz --outdir docs/frames/manual
julia --project scripts/visualize_arrays.jl --input docs/frames/manual --output docs/frames/manual/plots
```

`scripts/visualize_arrays.jl` options:

```text
--input DIR      Directory containing array_frame_*.jls
--output DIR     Directory where PNG plots are written
```

## Plot Domain Decomposition

Normal non-benchmark runs save domain-decomposition metadata to:

```text
OUTDIR/domain_decomposition.jls
```

Plot it with:

```bash
julia --project scripts/visualize_domain_decomposition.jl --input docs/frames/manual --output docs/frames/manual/domain_decomposition.png
```

`scripts/visualize_domain_decomposition.jl` options:

```text
--input PATH     Either an output directory or a domain_decomposition.jls file
--output PATH    Output PNG path
--no-roi         Do not draw the saved region-of-interest outline
```

## Slurm / Cluster Runs

For batch systems, use the same command inside the job script:

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 500 --ny 500 --nt 100 --benchmark
```

or:

```bash
mpiexec -n 4 julia --project src/manual.jl --nx 500 --ny 500 --nt 100 --benchmark
```

The repository also contains helper scripts in `run_files/`, but check them
before submitting because cluster account, module/uenv setup, number of tasks,
and GPU-related environment variables are machine-specific. Solvers use the CPU
backend by default; the CSCS scripts set `USE_GPU=true` for CUDA.

Topology/thread and aspect-ratio benchmark sweeps can be run locally with:

```bash
./run_files/run_manual_threads.sh 2x2
./run_files/run_manual_aspect_ratios.sh 2x2
```

The first command tests 1, 2, 4, and 8 Julia threads by default. The second
uses 8 threads and tests interior-grid ratios 1:8, 1:4, 1:2, and 1:1. Results
are written below `out/` with topology, thread count, and ratio labels. Use
environment variables printed by each script's usage message to override the
defaults.

On CSCS, the matching scripts submit themselves and calculate the required
MPI ranks, nodes, and GPUs from the topology:

```bash
./run_files/submit_manual_threads_cscs.sh 2x2
./run_files/submit_manual_aspect_ratios_cscs.sh 2x2
```

## Implementation Notes

`baseline.jl`:

- Uses `init_global_grid(...)` from `ImplicitGlobalGrid.jl`.
- Uses IGG helpers such as global indexing and `update_halo!`.
- Gathers field arrays and domain-decomposition metadata for external plotting.

`manual.jl`:

- Creates an MPI Cartesian communicator with `MPI.Cart_create`.
- Uses `MPI.Cart_shift` to find neighbors.
- Uses `MPI.Gatherv!` to gather local interiors to rank 0.
- Uses blocking `MPI.Sendrecv!` halo updates.
- Applies physical boundary conditions only on ranks at global boundaries.

Future work:

- Add nonblocking halo exchange and overlap with interior computation.
- Re-enable/validate GPU execution once the manual communication path is ready.
- Add comparison checks between `baseline.jl` and `manual.jl`.

## References

1. [S1ntax3rror/ShallowWater4PDEonGPU](https://github.com/S1ntax3rror/ShallowWater4PDEonGPU)
2. [eth-cscs/ImplicitGlobalGrid.jl](https://github.com/eth-cscs/ImplicitGlobalGrid.jl)
