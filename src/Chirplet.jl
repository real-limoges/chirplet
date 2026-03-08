module Chirplet

include("config.jl")

include("domain/domain.jl")
include("services/services.jl")
include("workflows/workflows.jl")

using .Domain
using .Services
using .Workflows

# Re-export Domain
export QualityRating, QA, QB, QC, QD, QE, QUnknown, parse_quality, meets_quality
export SoundType, Song, Call, Alarm, Flight, Drumming, Dawn, Other, UnknownType, parse_soundtype
export DataSource, XenoCanto, MacaulayLibrary, LocalFile
export GeoCoord, Species, RecordingMeta, Recording, RecordingFilter, matches

# Re-export Services
export StoreConfig, Store, open_store, close_store, save_recording, count_recordings, query_recordings
export XenoCantoConfig, RateLimiter, throttle!, build_query, fetch_page, parse_recording, fetch_all_recordings

# Re-export Workflows
export AcquisitionResult, acquire_recordings

# Re-export config
export load_toml

end
