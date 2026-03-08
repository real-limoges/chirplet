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
using DataFrames

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

    # Load TOML
    toml = if isfile(config_path)
        @info "Loading config from $config_path"
        load_toml(config_path)
    else
        @info "Using defaults (no config file found)"
        Dict{String,Any}()
    end

    # Build per-service configs from TOML sections
    paths = get(toml, "paths", Dict{String,Any}())
    api = get(toml, "api", Dict{String,Any}())
    sp = get(toml, "species", Dict{String,Any}())
    filt = get(toml, "filtering", Dict{String,Any}())

    store_cfg = StoreConfig(
        db_path = get(paths, "db_path", "data/chirplet.sqlite"),
    )

    xc_cfg = XenoCantoConfig(
        base_url = get(api, "xc_base_url", "https://xeno-canto.org/api/2/recordings"),
        api_key = get(ENV, "XENOCANTO_API_KEY", get(api, "xc_api_key", "")),
        rate_limit = get(api, "xc_rate_limit", 1000),
        request_delay = get(api, "xc_request_delay", 3.6),
    )

    species = Species(
        genus = get(sp, "target_genus", "Zonotrichia"),
        species = get(sp, "target_species", "leucophrys"),
        subspecies = get(sp, "target_subspecies", ""),
    )

    # CLI overrides for subspecies/country
    target_subspecies = species.subspecies
    target_country = get(sp, "target_country", "")

    ssp_idx = findfirst(==("--subspecies"), args)
    if ssp_idx !== nothing && ssp_idx < length(args)
        target_subspecies = args[ssp_idx + 1]
    end

    cnt_idx = findfirst(==("--country"), args)
    if cnt_idx !== nothing && cnt_idx < length(args)
        target_country = args[cnt_idx + 1]
    end

    # Max pages for testing
    mp_idx = findfirst(==("--max-pages"), args)
    if mp_idx !== nothing && mp_idx < length(args)
        max_pages = parse(Int, args[mp_idx + 1])
    end

    filter = RecordingFilter(
        min_quality = parse_quality(get(filt, "min_quality", "C")),
        require_coords = get(filt, "require_coords", true),
        sound_types = parse_soundtype.(get(filt, "sound_types", ["song"])),
        country = target_country,
        subspecies = target_subspecies,
    )

    # Ensure data directories exist
    for dir_key in ["data_dir", "raw_dir", "processed_dir", "cache_dir"]
        dir = get(paths, dir_key, nothing)
        dir !== nothing && mkpath(dir)
    end

    # Open store
    mkpath(dirname(store_cfg.db_path))
    store = open_store(store_cfg)

    # Create closures over services for workflow injection
    limiter = RateLimiter(xc_cfg.request_delay)

    fetch_page_fn = (sp, page) -> begin
        throttle!(limiter)
        fetch_page(xc_cfg, limiter, build_query(sp, xc_cfg), page)
    end

    save_recording_fn = (rec) -> save_recording(store, rec)

    # Run acquisition workflow
    result = acquire_recordings(
        fetch_page = fetch_page_fn,
        save_recording = save_recording_fn,
        filter = filter,
        species = species,
        max_pages = max_pages,
    )

    # Summary
    println("\n── Summary ──")
    println("  ", result)

    # Quick stats
    total = count_recordings(store)
    println("\n  Total recordings in store: $total")

    df = query_recordings(store; filter=RecordingFilter(require_coords=true))
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
