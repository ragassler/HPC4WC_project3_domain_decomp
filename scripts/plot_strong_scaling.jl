using CairoMakie
using Statistics

baseline_path = "output/strong_scaling_baseline.csv"
manual_path = "output/strong_scaling_manual.csv"
output_path = "output/strong_scaling_throughput.png"

i = 1
while i <= length(ARGS)
    if ARGS[i] == "--baseline"
        i < length(ARGS) || error("--baseline requires a CSV path")
        global baseline_path = ARGS[i + 1]
        global i += 2
    elseif ARGS[i] == "--manual"
        i < length(ARGS) || error("--manual requires a CSV path")
        global manual_path = ARGS[i + 1]
        global i += 2
    elseif ARGS[i] == "--output"
        i < length(ARGS) || error("--output requires a PNG path")
        global output_path = ARGS[i + 1]
        global i += 2
    else
        error("Unknown argument: $(ARGS[i])")
    end
end

function read_scaling_csv(path)
    isfile(path) || error("Strong-scaling CSV not found: $path")
    lines = filter(!isempty, strip.(readlines(path)))
    isempty(lines) && error("Strong-scaling CSV is empty: $path")

    header = split(first(lines), ',')
    columns = Dict(name => i for (i, name) in enumerate(header))
    required = ["topology", "nx_global", "ny_global", "cell_updates_per_second"]
    missing_columns = filter(name -> !haskey(columns, name), required)
    isempty(missing_columns) ||
        error("Missing columns in $path: $(join(missing_columns, ", "))")

    return map(lines[2:end]) do line
        fields = split(line, ',')
        length(fields) == length(header) || error("Malformed CSV row in $path: $line")
        (
            topology = fields[columns["topology"]],
            global_cells = parse(Int, fields[columns["nx_global"]]) *
                           parse(Int, fields[columns["ny_global"]]),
            throughput = parse(Float64, fields[columns["cell_updates_per_second"]]) / 1e9,
        )
    end
end

function averaged_curve(rows)
    throughput_by_size = Dict{Int, Vector{Float64}}()
    for row in rows
        push!(get!(throughput_by_size, row.global_cells, Float64[]), row.throughput)
    end

    x = sort(collect(keys(throughput_by_size)))
    y = [mean(throughput_by_size[cells]) for cells in x]
    return x, y
end

function topology_order(topology)
    dims = parse.(Int, split(topology, 'x'))
    length(dims) == 2 || error("Invalid topology: $topology")
    return Tuple(dims)
end

function superscript_integer(value)
    digits = Dict(
        '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴',
        '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹',
        '-' => '⁻',
    )
    return join(digits[character] for character in string(value))
end

baseline_rows = read_scaling_csv(baseline_path)
manual_rows = read_scaling_csv(manual_path)
isempty(baseline_rows) && error("No data rows found in $baseline_path")
isempty(manual_rows) && error("No data rows found in $manual_path")

all_global_cells = vcat(
    [row.global_cells for row in baseline_rows],
    [row.global_cells for row in manual_rows],
)
first_exponent = floor(Int, log2(minimum(all_global_cells)))
last_exponent = ceil(Int, log2(maximum(all_global_cells)))
tick_exponents = collect(first_exponent:2:last_exponent)
power_of_two_ticks = (
    exp2.(tick_exponents),
    ["2$(superscript_integer(exponent))" for exponent in tick_exponents],
)

fig = Figure(size = (1200, 680); backgroundcolor = :white)
ax = Axis(fig[1, 1];
    title = "Strong Scaling Performance Comparison",
    xlabel = "Global Problem Size (nx × ny)",
    ylabel = "Throughput (GCell updates/s)",
    xscale = log2,
    xticks = power_of_two_ticks,
    backgroundcolor = RGBf(0.90, 0.90, 0.90),
    xgridcolor = :white,
    ygridcolor = :white,
    xgridwidth = 1.5,
    ygridwidth = 1.5,
    titlesize = 26,
    titlefont = :bold,
    xlabelsize = 21,
    ylabelsize = 21,
    xticklabelsize = 17,
    yticklabelsize = 17,
)

baseline_x, baseline_y = averaged_curve(baseline_rows)
scatterlines!(ax, baseline_x, baseline_y;
    label = "Baseline",
    color = :black,
    linewidth = 3,
    marker = :circle,
    markersize = 14,
)

manual_topologies = sort(unique(row.topology for row in manual_rows); by = topology_order)
colors = [:dodgerblue, :darkorange, :seagreen, :purple, :crimson]
markers = [:rect, :diamond, :utriangle, :dtriangle, :pentagon]

for (i, topology) in enumerate(manual_topologies)
    rows = filter(row -> row.topology == topology, manual_rows)
    x, y = averaged_curve(rows)
    color = colors[mod1(i, length(colors))]
    marker = markers[mod1(i, length(markers))]
    label = "Manual $(replace(topology, "x" => "×"))"

    scatterlines!(ax, x, y;
        label,
        color,
        marker,
        linewidth = 2.5,
        markersize = 13,
    )
end

axislegend(ax;
    position = :rb,
    framevisible = true,
    backgroundcolor = RGBAf(0.97, 0.97, 0.97, 0.92),
    labelsize = 16,
)

mkpath(dirname(output_path))
save(output_path, fig)
println("saved ", output_path)
