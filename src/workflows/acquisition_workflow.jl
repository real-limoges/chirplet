Base.@kwdef struct AcquisitionResult
    total_fetched::Int = 0
    total_matched::Int = 0
    total_saved::Int = 0
    pages_fetched::Int = 0
end

function Base.show(io::IO, r::AcquisitionResult)
    print(io, "Acquisition: $(r.total_fetched) fetched, $(r.total_matched) matched filter, $(r.total_saved) saved ($(r.pages_fetched) pages)")
end

function acquire_recordings(;
    fetch_page,
    save_recording,
    filter::RecordingFilter,
    species::Species,
    max_pages::Union{Int,Nothing} = nothing,
)
    result = AcquisitionResult()
    page = 1
    total_pages = 1

    while page <= total_pages
        if max_pages !== nothing && page > max_pages
            break
        end

        recordings, total_pages = fetch_page(species, page)
        result = AcquisitionResult(
            total_fetched = result.total_fetched + length(recordings),
            total_matched = result.total_matched,
            total_saved = result.total_saved,
            pages_fetched = page,
        )

        for meta in recordings
            if matches(filter, meta)
                rec = Recording(meta)
                save_recording(rec)
                result = AcquisitionResult(
                    total_fetched = result.total_fetched,
                    total_matched = result.total_matched + 1,
                    total_saved = result.total_saved + 1,
                    pages_fetched = result.pages_fetched,
                )
            end
        end

        page += 1
    end

    return result
end
