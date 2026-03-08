# ----- Filtering ----- #

Base.@kwdef struct RecordingFilter
    min_quality::QualityRating = QC
    require_coords::Bool = true
    sound_types::Vector{SoundType} = [Song]
    country::String = ""
    subspecies::String = ""
    date_range::Union{Tuple{Date,Date},Nothing} = nothing
end

function matches(filter::RecordingFilter, meta::RecordingMeta)::Bool
    meets_quality(meta.quality, filter.min_quality) || return false
    filter.require_coords && meta.coord === nothing && return false
    meta.sound_type in filter.sound_types || return false
    !isempty(filter.country) && meta.country != filter.country && return false
    !isempty(filter.subspecies) && meta.species.subspecies != filter.subspecies && return false
    if filter.date_range !== nothing && meta.date !== nothing
        lo, hi = filter.date_range
        lo <= meta.date <= hi || return false
    end
    return true
end
