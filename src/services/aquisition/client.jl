Base.@kwdef struct XenoCantoConfig
    base_url::String = "https://xeno-canto.org/api/2/recordings"
    api_key::String = ""
    rate_limit::Int = 1000
    request_delay::Float64 = 3.6
end

mutable struct RateLimiter
    min_delay_sec::Float64
    last_request::Float64
end
RateLimiter(delay::Float64) = RateLimiter(delay, 0.0)

function throttle!(limiter::RateLimiter)
    elapsed = time() - limiter.last_request
    if elapsed < limiter.min_delay_sec
        sleep(limiter.min_delay_sec - elapsed)
    end
    limiter.last_request = time()
end

function build_query(species::Species, cfg::XenoCantoConfig)
    # Build xeno-canto query string from species info
    query = "$(species.genus) $(species.species)"
    query
end

function fetch_page(cfg::XenoCantoConfig, limiter::RateLimiter, query::String, page::Int)
    # Fetch a single page of results from xeno-canto API
    # Returns (recordings::Vector{RecordingMeta}, total_pages::Int)
    error("fetch_page not yet implemented")
end

function parse_recording(data::Dict)::RecordingMeta
    # Parse a single xeno-canto JSON recording into RecordingMeta
    error("parse_recording not yet implemented")
end

function fetch_all_recordings(cfg::XenoCantoConfig, species::Species; max_pages::Union{Int,Nothing}=nothing)
    # Fetch all pages of recordings for a species
    # Returns Vector{RecordingMeta}
    error("fetch_all_recordings not yet implemented")
end
