#!/usr/bin/env julia
#
# Acquire White-crowned Sparrow recordings from xeno-canto.
#
# Usage:
#   julia --project=. scripts/acquire.jl                    # metadata only
#   julia --project=. scripts/acquire.jl --download          # metadata + audio
#   julia --project=. scripts/acquire.jl --config path.toml  # custom config
#   julia --project=. scripts/acquire.jl --subspecies nuttalli --country "United States"
#
# Or from the REPL:
#   include("scripts/acquire.jl")

using Chirplet

function main(args=ARGS)
    # Parse simple CLI args
    download_audio = "--download" in args
    max_pages = nothing

    # Config file
    config_path = joinpath(@__DIR__, "..", "config", "default.toml")
    config_idx = findfirst(==("--config"), args)
    if config_idx !== nothing && config_idx < length(args)
        config_path = args[config_idx + 1]
    end

    # Load config
    cfg = if isfile(config_path)
        @info "Loading config from $config_path"
        load_config(config_path)
    else
        @info "Using default config"
        default_config()
    end

    # Override subspecies if specified
    ssp_idx = findfirst(==("--subspecies"), args)
    if ssp_idx !== nothing && ssp_idx < length(args)
        cfg = ChirpletConfig(cfg; target_subspecies=args[ssp_idx + 1])
    end

    # Override country if specified
    cnt_idx = findfirst(==("--country"), args)
    if cnt_idx !== nothing && cnt_idx < length(args)
        cfg = ChirpletConfig(cfg; target_country=args[cnt_idx + 1])
    end

    # Max pages for testing
    mp_idx = findfirst(==("--max-pages"), args)
    if mp_idx !== nothing && mp_idx < length(args)
        max_pages = parse(Int, args[mp_idx + 1])
    end

    # Ensure directories exist
    ensure_dirs!(cfg)

    # Build and run pipeline
    pipeline = Pipeline(cfg)
    push!(pipeline, AcquisitionStage(
        download_audio = download_audio,
        max_pages = max_pages,
    ))

    results = run_pipeline(pipeline)

    # Summary
    println("\n── Summary ──")
    for r in results
        println("  ", r)
    end

    # Quick stats
    store = open_store(cfg)
    total = count_recordings(store)
    println("\n  Total recordings in store: $total")

    df = query_recordings(store; with_coords_only=true)
    println("  With coordinates: $(nrow(df))")

    if nrow(df) > 0
        println("  Lat range: $(minimum(df.lat)) to $(maximum(df.lat))")
        println("  Lng range: $(minimum(df.lng)) to $(maximum(df.lng))")

        # Subspecies breakdown
        ssp_counts = combine(groupby(df, :subspecies), nrow => :count)
        println("  Subspecies:")
        for row in eachrow(ssp_counts)
            label = isempty(row.subspecies) || ismissing(row.subspecies) ? "(unspecified)" : row.subspecies
            println("    $label: $(row.count)")
        end

        # Quality breakdown
        q_counts = combine(groupby(df, :quality), nrow => :count)
        println("  Quality:")
        for row in eachrow(q_counts)
            println("    $(row.quality): $(row.count)")
        end
    end

    close_store(store)
end

# Run if called as script; skip if just included
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
