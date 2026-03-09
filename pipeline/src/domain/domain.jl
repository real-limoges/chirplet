module Domain

using Dates, UUIDs

include("types.jl")
include("filters.jl")

export QualityRating, QA, QB, QC, QD, QE, QUnknown, parse_quality, meets_quality
export SoundType, Song, Call, Alarm, Flight, Drumming, Dawn, Other, UnknownType, parse_soundtype
export DataSource, XenoCanto, MacaulayLibrary, LocalFile
export GeoCoord, Species, RecordingMeta, Recording, RecordingFilter, matches

end
