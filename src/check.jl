using ImplicitGlobalGrid

function main()
    # Local grid size on every MPI rank.
    nx, ny, nz = 16, 16, 1

    # Same lifecycle as the porous-convection example:
    # ImplicitGlobalGrid initializes MPI and chooses the process topology.
    me, dims = init_global_grid(
        nx, ny, nz;
        select_device = false
    )

    println("Rank $me initialized; process-grid dimensions = $(Tuple(dims))")
    flush(stdout)

    println("Rank $me entering finalize_global_grid()")
    flush(stdout)

    finalize_global_grid()

    # Seeing this line means finalize_global_grid() returned successfully.
    println("Rank $me returned from finalize_global_grid()")
    flush(stdout)

    return nothing
end

main()
