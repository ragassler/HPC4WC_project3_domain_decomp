#!/bin/bash

# ==============================================================================
# PARAMETER-EINSTELLUNGEN (Lokal)
# ==============================================================================
NX=16386
NY=4098
RUNS=1
PROCS=4
CSV_FILE="docs/benchmark/gpu_topo_4_ranks.csv"
SCRIPT="src/manual_2.jl"

# Optional: GPU-Umgebungsvariablen
export MPICH_GPU_SUPPORT_ENABLED=1
export IGG_CUDAAWARE_MPI=1
export JULIA_CUDA_USE_COMPAT=false
export USE_GPU=false

# Ordner für CSV-Ergebnisse anlegen
mkdir -p docs/benchmark

# ==============================================================================
# BENCHMARK VIA JULIA MPI.mpiexec()
# ==============================================================================
julia --project -e '
using MPI

nx       = ARGS[1]
ny       = ARGS[2]
runs     = ARGS[3]
procs    = parse(Int, ARGS[4])
csv_file = ARGS[5]
script   = ARGS[6]

topologies = ["(4,1)", "(2,2)", "(1,4)"]

for topo in topologies
    println("\n==================================================")
    println(" Starte Topologie: ", topo, " (mit ", procs, " Prozessen)")
    println("==================================================")
    
    # Aufruf über MPI.mpiexec() mit den Flags aus manual_2.jl
    run(`$(MPI.mpiexec()) -n $procs julia --project $script --topo $topo --nx $nx --ny $ny --runs $runs --benchmark false --benchdir $csv_file`)
    
    println("Topologie ", topo, " abgeschlossen.\n")
end
println("Alle Benchmarks erfolgreich beendet!")
' "$NX" "$NY" "$RUNS" "$PROCS" "$CSV_FILE" "$SCRIPT"