using Serialization
using Printf
using Statistics
using CairoMakie

input_path = "docs/frames/baseline"
output_path = nothing
show_roi = true

i = 1
while i <= length(ARGS)
    if ARGS[i] == "--input"
        global input_path = ARGS[i + 1]
        global i += 2
    elseif ARGS[i] == "--output"
        global output_path = ARGS[i + 1]
        global i += 2
    elseif ARGS[i] == "--no-roi"
        global show_roi = false
        global i += 1
    else
        error("Unknown argument: $(ARGS[i])")
    end
end

input_file = isdir(input_path) ? joinpath(input_path, "domain_decomposition.jls") : input_path
isfile(input_file) || error("Domain decomposition file not found: $input_file")

if output_path === nothing
    output_path = joinpath(dirname(input_file), "domain_decomposition.png")
end

decomp = deserialize(input_file)
rank = Float64.(Array(decomp.rank))
nx, ny = size(rank)
ranks = sort(unique(vec(rank)))

fig = Figure(size = (980, 820))
title = hasproperty(decomp, :dims) ?
    "MPI domain decomposition ($(decomp.dims[1]) x $(decomp.dims[2]))" :
    "MPI domain decomposition"

ax = Axis(fig[1, 1];
    title = title,
    xlabel = "global interior x index",
    ylabel = "global interior y index",
    aspect = DataAspect(),
)

hm = heatmap!(ax, 1:nx, 1:ny, rank;
    colormap = cgrad(:tab10, max(length(ranks), 1), categorical = true),
)
Colorbar(fig[1, 2], hm, label = "MPI rank")

for ix in 1:(nx - 1)
    if any(rank[ix, :] .!= rank[ix + 1, :])
        lines!(ax, [ix + 0.5, ix + 0.5], [0.5, ny + 0.5]; color = :black, linewidth = 2)
    end
end

for iy in 1:(ny - 1)
    if any(rank[:, iy] .!= rank[:, iy + 1])
        lines!(ax, [0.5, nx + 0.5], [iy + 0.5, iy + 0.5]; color = :black, linewidth = 2)
    end
end

for r in ranks
    idx = findall(==(r), rank)
    isempty(idx) && continue
    xs = [idxi[1] for idxi in idx]
    ys = [idxi[2] for idxi in idx]
    text!(ax, mean(xs), mean(ys);
        text = @sprintf("%d", round(Int, r)),
        align = (:center, :center),
        color = :white,
        fontsize = 24,
        font = :bold,
    )
end

if show_roi && hasproperty(decomp, :roi_indices)
    ix_roi, iy_roi = decomp.roi_indices
    ix_plot = clamp.(ix_roi .- 1, 1, nx)
    iy_plot = clamp.(iy_roi .- 1, 1, ny)

    if !isempty(ix_plot) && !isempty(iy_plot)
        x0, x1 = first(ix_plot) - 0.5, last(ix_plot) + 0.5
        y0, y1 = first(iy_plot) - 0.5, last(iy_plot) + 0.5
        lines!(ax, [x0, x1, x1, x0, x0], [y0, y0, y1, y1, y0];
            color = :red,
            linewidth = 3,
        )
    end
end

xlims!(ax, 0.5, nx + 0.5)
ylims!(ax, 0.5, ny + 0.5)

mkpath(dirname(output_path))
save(output_path, fig)
println("saved ", output_path)
