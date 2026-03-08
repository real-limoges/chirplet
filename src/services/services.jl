module Services

using ..Domain
using SQLite, DBInterface, DataFrames, JSON3, Dates, UUIDs

include("store/schema.jl")
include("store/store.jl")
include("aquisition/client.jl")

export StoreConfig, Store, open_store, close_store, save_recording, count_recordings, query_recordings
export XenoCantoConfig, RateLimiter, throttle!, build_query, fetch_page, parse_recording, fetch_all_recordings

end
