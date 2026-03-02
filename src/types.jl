using StructTypes

# ----- Sum Types ----- #

@enum QualityRating QA QB QC QD QE QUnknown
function parse_quality(s::AbstractString)
    s = strip(uppercase(s))
    s == "A" ? QA :
    s == "B" ? QB :
    s == "C" ? QC :
    s == "D" ? QD :
    s == "E" ? QE : QUnknown
end
Base.isless(a::QualityRating, b::QualityRating) = Int(a) > Int(b)
meets_quality(rating::QualityRating, minimum::QualityRating) = Int(rating) <= Int(minimum)


@enum SoundType Song Call Alarm Flight Drumming Dawn Other UnknownType
function parse_soundtype(s::AbstractString)
    s = lowercase(strip(s))
    contains(s, "song") ? Song :
    contains(s, "call") ? Call :
    contains(s, "alarm") ? Alarm :
    contains(s, "flight") ? Flight :
    contains(s, "drumming") ? Drumming :
    contains(s, "dawn") ? Dawn : Other
end

@enum DataSource XenoCanto MacaulayLibrary LocalFile

# ----- Value Types ----- #

struct GeoCoord
    lng::Float64
    lat::Float64
    elevation::Union{Float64,Nothing}
end
GeoCoord(lng, lat) = GeoCoord(Float64(lng), Float64(lat), nothing)
Base.isvalid(g::GeoCoord) = -90 <= g.lat <= 90 && -180 <= g.lng <= 180
Base.show(io::IO, g::GeoCoord) = print(io, "($(round(g.lat; digits=4)), $(round(g.lng; digits=4)))")


# ----- Recordings ----- #
Base.@kwdef struct RecordingMeta
    source::DataSource
    source_id::String
    species::Species
    coord::Union{GeoCoord,Nothing} = nothing
    quality::QualityRating = QUnknown
    sound_type::SoundType = UnknownType
    date::Union{Date,Nothing} = nothing
    time::Union{Time,Nothing} = nothing
    country::String = ""
    location::String = ""
    recordist::String = ""
    license::String = ""
    url::String = ""
    audio_url::String = ""
    duration_s::Union{Float64,Nothing} = nothing
    sample_rate::Union{Int,Nothing} = nothing
    remarks::String = ""
end

struct Recording
    id::UUID
    meta::RecordingMeta
    audio_path::Union{String,Nothing}
    downloaded::Bool
    created_at::DateTime
end

function Recording(meta::RecordingMeta; audio_path=nothing)
    Recording(
        uuid4(), meta, audio_path,
        audio_path !== nothing && isfile(something(audio_path, "")),
        now()
    )
end



# ----- Filtering ----- #
Base.@kwdef struct RecordingFilter
    min_quality::QualityRating = QC
    require_coords::Bool = true
    sound_types::Vector{SoundType} = [Song]
    country::String = ""
    subspecies::String = ""
    date_range::Union{Tuple{Date,Date},Nothing} = nothing
end

RecordingFilter(cfg::ChirpletConfig)


# ----- Pipelines ----- #