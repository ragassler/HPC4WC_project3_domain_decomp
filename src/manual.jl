using MPI
using ImplicitGlobalGrid

function main()
    # Own MPI explicitly and disable MPI.jl's automatic atexit hook.
    provided = MPI.Init(
        threadlevel = :serialized,
        finalize_atexit = false
    )

    me, dims = init_global_grid(
        16, 16, 1;
        init_MPI = false,
        select_device = false
    )

    println(
        "Rank $me initialized; dims=$(Tuple(dims)); " *
        "thread support=$provided"
    )
    flush(stdout)

    # Destroy the IGG grid, but do not finalize MPI through IGG.
    finalize_global_grid(finalize_MPI = false)

    println("Rank $me finalized IGG")
    flush(stdout)

    # Explicitly finalize MPI.
    MPI.Finalize()

    println(
        "Rank $me returned from MPI.Finalize(); " *
        "MPI.Finalized()=$(MPI.Finalized())"
    )
    flush(stdout)

    return nothing
end

main()