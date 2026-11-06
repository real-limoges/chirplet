module Chirplet

include("config.jl")

include("domain/domain.jl")
include("services/services.jl")
include("workflows/workflows.jl")

using .Domain
using .Services
using .Workflows

# Re-exports, grouped by submodule in include order.
export QualityRating, QA, QB, QC, QD, QE, QUnknown, parse_quality, meets_quality
export SoundType, Song, Call, Alarm, Flight, Drumming, Dawn, Other, UnknownType, parse_soundtype
export DataSource, XenoCanto, MacaulayLibrary, LocalFile
export GeoCoord, Species, RecordingMeta, Recording, RecordingFilter, matches

export StoreConfig, Store, open_store, close_store, save_recording, count_recordings, query_recordings
export pending_downloads, mark_downloaded!
export XenoCantoConfig, RateLimiter, throttle!, build_query, fetch_page, parse_recording, download_audio_file

export AcquisitionResult, acquire_recordings
export DownloadResult, download_recordings

export load_toml

end
