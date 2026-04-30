#!/usr/bin/env julia
#
# Acquire White-crowned Sparrow recordings from xeno-canto.
#
# Usage:
#   julia --project=. scripts/acquire.jl                  # full run
#   julia --project=. scripts/acquire.jl --max-pages 1    # smoke test
#
# Edit pipeline/config/default.toml to change species, filters, or paths.

using Chirplet
using DataFrames

function main(args=ARGS)
    max_pages = nothing
    mp_idx = findfirst(==("--max-pages"), args)
    if mp_idx !== nothing && mp_idx < length(args)
        max_pages = parse(Int, args[mp_idx + 1])
    end

    project_root = dirname(@__DIR__)
    resolve = path -> joinpath(project_root, path)

    config_path = joinpath(project_root, "config", "default.toml")
    @info "Loading config from $config_path"
    toml = load_toml(config_path)

    paths = toml["paths"]
    api = toml["api"]
    sp_cfg = toml["species"]
    filt = toml["filtering"]

    api_key = get(ENV, "XENOCANTO_API_KEY", get(api, "xc_api_key", ""))
    isempty(api_key) && error("XENOCANTO_API_KEY env var is not set (and no xc_api_key in config). " *
                              "Get a key at https://xeno-canto.org/account.")

    store_cfg = StoreConfig(db_path = resolve(paths["db_path"]))

    xc_cfg = XenoCantoConfig(
        base_url = api["xc_base_url"],
        api_key = api_key,
        request_delay = api["xc_request_delay"],
    )

    species = Species(
        genus = sp_cfg["target_genus"],
        species = sp_cfg["target_species"],
        subspecies = get(sp_cfg, "target_subspecies", ""),
    )

    rec_filter = RecordingFilter(
        min_quality = parse_quality(filt["min_quality"]),
        require_coords = filt["require_coords"],
        sound_types = parse_soundtype.(filt["sound_types"]),
        country = get(sp_cfg, "target_country", ""),
        subspecies = species.subspecies,
    )

    for dir_key in ["data_dir", "raw_dir", "processed_dir", "cache_dir"]
        dir = get(paths, dir_key, nothing)
        dir !== nothing && mkpath(resolve(dir))
    end
    mkpath(dirname(store_cfg.db_path))

    store = open_store(store_cfg)
    limiter = RateLimiter(xc_cfg.request_delay)

    result = acquire_recordings(
        fetch_page = (target, page) -> fetch_page(xc_cfg, limiter, build_query(target, xc_cfg), page),
        save_recording = rec -> save_recording(store, rec),
        filter = rec_filter,
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
