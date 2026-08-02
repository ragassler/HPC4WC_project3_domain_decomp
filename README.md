# HPC4WC Project 3: Domain Decomposition SWE

Small 2D shallow-water-equation solver used to study domain decomposition and
MPI halo exchange. The project currently contains two main solver variants:

- `src/baseline.jl`: baseline implementation using `ImplicitGlobalGrid.jl`.
- `src/manual.jl`: manual MPI Cartesian-domain-decomposition version without
  `ImplicitGlobalGrid.jl`.

Both versions use `ParallelStencil` kernels. `manual.jl` selects the CPU backend
by default and switches to CUDA when the environment variable `USE_GPU=true`.
At present, `baseline.jl` has `USE_GPU = true` set directly in the source; set
that constant to `false` before using the baseline CPU commands below.

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

Options shared by `src/baseline.jl` and `src/manual.jl`:

```text
--nx N          Global x size including outer halos/default boundary cells
--ny N          Global y size including outer halos/default boundary cells
--nt N          Number of timesteps
--outdir DIR    Directory for saved arrays and domain-decomposition metadata
--benchmark     Run timing mode: no saved arrays, no progress output
--warmup N      Warm-up iterations excluded from benchmark timing
--benchdir FILE CSV file to which benchmark results are appended
--test           Run against reference test data
--test-file FILE Reference-data file used by --test
```

Solver-specific options:

```text
baseline.jl: --viz             Save serialized field arrays for later plotting
manual.jl:   --topo "(PX,PY)"  MPI Cartesian topology (default "(2,2)")
manual.jl:   --runs N          Number of timed benchmark repetitions (default 10)
```

`baseline.jl` lets `ImplicitGlobalGrid.jl`/MPI choose a compact Cartesian
topology from the number of MPI ranks. `manual.jl` accepts its topology with
`--topo "(PX,PY)"` and must use `PX * PY` MPI ranks. In both cases, the global
interior size `nx - 2` by `ny - 2` must be divisible by the chosen topology.

## CPU Launches

Use the MPI launcher that belongs to `MPI.jl`; the setup command above prints
its path. The examples below follow the argument form used by
`run_files/run_strong_scaling.sh`, but use a small CPU-friendly grid.

`manual.jl` runs on the CPU by default. Setting `USE_GPU=false` explicitly makes
the intended backend clear:

```bash
USE_GPU=false mpiexec -n 4 julia -t 1 --project=. src/manual.jl \
    --topo "(2,2)" \
    --nx 1026 --ny 258 --nt 20 \
    --warmup 5 --runs 1 --benchmark \
    --benchdir output/cpu_manual.csv \
    --outdir output/cpu_manual
```

The topology product must equal the MPI process count; for example, `"(2,2)"`
requires four ranks.

### Baseline CPU launch

`baseline.jl` uses `ImplicitGlobalGrid.jl` for the Cartesian decomposition,
global indices, and halo updates. The topology is selected automatically from
the number of MPI ranks. Because its backend is currently fixed in the source,
first set `const USE_GPU = false` near the top of `src/baseline.jl`, then run:

```bash
mpiexec -n 4 julia -t 1 --project=. src/baseline.jl \
    --nx 1026 --ny 258 --nt 20 \
    --warmup 5 --benchmark \
    --benchdir output/cpu_baseline.csv \
    --outdir output/cpu_baseline
```

Equivalent launch using the MPI selected by the Julia environment:

```bash
julia --project=. -e 'using MPI; run(`$(MPI.mpiexec()) -n 4 julia -t 1 --project=. src/baseline.jl --nx 1026 --ny 258 --nt 20 --warmup 5 --benchmark --benchdir output/cpu_baseline.csv --outdir output/cpu_baseline`)'
```

For a normal, non-benchmark baseline run, omit `--benchmark`. Add `--viz` to
save field arrays. A normal manual run also omits `--benchmark`; it currently
saves visualization data by default.

Benchmark CSV rows include the solver, process topology, global/local sizes,
runtime, steps per second, and cell updates per second. The manual solver writes
one row per `--runs` repetition.

## GPU / CSCS Launches

GPU launches, Slurm resource requests, CUDA-aware MPI variables, and CSCS uenv
settings are provided in the shell scripts under `run_files/`. In particular:

```bash
run_files/run_strong_scaling.sh
run_files/run_cluster_4_ranks.sh
run_files/run_cluster_16_ranks.sh
```

Inspect and adapt the relevant `.sh` file before submission because account,
paths, node counts, task counts, and uenv settings are cluster-specific. The
strong-scaling script is the canonical example of the current solver flags.

## Save And Plot Field Arrays

Use `--viz` to save serialized arrays in `--outdir`. The solver writes files
named `array_frame_*.jls`. Plot them afterwards with:

```bash
mpiexec -n 4 julia --project src/baseline.jl --nx 80 --ny 80 --nt 20 --viz --outdir docs/frames/baseline
julia --project scripts/visualize_arrays.jl --input docs/frames/baseline --output docs/frames/baseline/plots
```

The same workflow works for `src/manual.jl` (which saves frames by default in a
non-benchmark run):

```bash
USE_GPU=false mpiexec -n 4 julia --project=. src/manual.jl --topo "(2,2)" --nx 82 --ny 82 --nt 20 --outdir docs/frames/manual
julia --project scripts/visualize_arrays.jl --input docs/frames/manual --output docs/frames/manual/plots
```

`scripts/visualize_arrays.jl` options:

```text
--input DIR      Directory containing array_frame_*.jls
--output DIR     Directory where PNG plots are written
```

## Plot Domain Decomposition

The benchmark `gpu_topo*.csv` files contain the topology and global/local grid
sizes needed to reconstruct the rectangular domain decomposition.

Plot it with:

```bash
julia --project scripts/visualize_domain_decomposition.jl --input output/gpu_topo_16_ranks_v3.csv --output output
```

`scripts/visualize_domain_decomposition.jl` options:

```text
--input PATH     A gpu_topo CSV or a directory containing gpu_topo*.csv files
--output PATH    Output directory or filename whose basename should be used
```

The plot is built directly from the CSV's topology and global/local grid-size
columns. It does not load the large serialized domain arrays. Every run writes
both `domain_decompositions.png` and `domain_decompositions.pdf` (or the basename
given with `--output`).

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
- Add different sizes of localgrids

## References

1. [S1ntax3rror/ShallowWater4PDEonGPU](https://github.com/S1ntax3rror/ShallowWater4PDEonGPU)
2. [eth-cscs/ImplicitGlobalGrid.jl](https://github.com/eth-cscs/ImplicitGlobalGrid.jl)
