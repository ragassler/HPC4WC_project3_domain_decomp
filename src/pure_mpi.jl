using MPI

MPI.Init(
    threadlevel = :serialized,
    finalize_atexit = false
)

rank = MPI.Comm_rank(MPI.COMM_WORLD)

println("Rank $rank initialized")
flush(stdout)

MPI.Barrier(MPI.COMM_WORLD)
MPI.Finalize()

println("Rank $rank finalized MPI")
flush(stdout)