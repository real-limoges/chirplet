Base.@kwdef struct DownloadResult
    total::Int = 0
    downloaded::Int = 0
    skipped::Int = 0
    failed::Int = 0
end

function Base.show(io::IO, r::DownloadResult)
    print(io, "Download: $(r.downloaded) downloaded, $(r.skipped) skipped (already on disk), $(r.failed) failed (of $(r.total))")
end

function download_recordings(;
    pending,                 # iterable of (source, source_id, audio_url, audio_filename)
    fetch_audio,             # (url, path) -> path
    mark_downloaded,         # (source, source_id, path) -> nothing
    dest_path_for,           # (source, source_id, audio_filename) -> String
    throttle = () -> nothing,
)
    total = length(pending)
    downloaded = 0
    skipped = 0
    failed = 0

    for (i, p) in enumerate(pending)
        path = dest_path_for(p.source, p.source_id, p.audio_filename)

        if isfile(path)
            mark_downloaded(p.source, p.source_id, path)
            skipped += 1
            continue
        end

        throttle()
        try
            fetch_audio(p.audio_url, path)
            mark_downloaded(p.source, p.source_id, path)
            downloaded += 1
            @info "[$i/$total] $(p.source_id) → $(basename(path))"
        catch e
            e isa InterruptException && rethrow()
            failed += 1
            @warn "[$i/$total] $(p.source_id) failed: $e"
        end
    end

    DownloadResult(total=total, downloaded=downloaded, skipped=skipped, failed=failed)
end
