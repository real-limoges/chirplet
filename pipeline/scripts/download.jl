#!/usr/bin/env julia
#
# Download audio files for all recordings in the store that don't have them yet.
#
# Usage:
#   julia --project=. scripts/download.jl
#
# Resumable: only fetches rows where downloaded = 0. Files already on disk
# are marked as downloaded without re-fetching.

using Chirplet

function main()
    project_root = dirname(@__DIR__)
    resolve = path -> joinpath(project_root, path)

    config_path = joinpath(project_root, "config", "default.toml")
    @info "Loading config from $config_path"
    toml = load_toml(config_path)

    paths = toml["paths"]
    api = toml["api"]

    raw_dir = resolve(paths["raw_dir"])
    mkpath(raw_dir)

    store = open_store(StoreConfig(db_path = resolve(paths["db_path"])))
    pending = pending_downloads(store)
    @info "$(length(pending)) recordings pending download"

    limiter = RateLimiter(api["xc_request_delay"])

    dest_path_for = (source, source_id, audio_filename) -> begin
        fname = isempty(audio_filename) ? "XC$(source_id).mp3" : audio_filename
        joinpath(raw_dir, fname)
    end

    result = download_recordings(
        pending = pending,
        fetch_audio = download_audio_file,
        mark_downloaded = (src, sid, path) -> mark_downloaded!(store, src, sid, path),
        dest_path_for = dest_path_for,
        throttle = () -> throttle!(limiter),
    )

    println("\n── Summary ──")
    println("  ", result)

    close_store(store)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
