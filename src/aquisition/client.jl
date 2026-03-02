
mutable struct RateLimiter
    min_delay_sec::Float64
    last_request::Float64
end