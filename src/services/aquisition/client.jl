Base.@kwdef struct XenoCantoConfig
    base_url::String = "https://xeno-canto.org/api/3/recordings"
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
    query = "gen:\"$(species.genus)\" sp:\"$(species.species)\""
    if !isempty(species.subspecies)
        query *= " ssp:\"$(species.subspecies)\""
    end
    query
end

function fetch_page(cfg::XenoCantoConfig, limiter::RateLimiter, query::String, page::Int)
    params = "query=$(HTTP.URIs.escapeuri(query))&page=$page"
    if !isempty(cfg.api_key)
        params *= "&key=$(HTTP.URIs.escapeuri(cfg.api_key))"
    end
    url = "$(cfg.base_url)?$params"
    resp = HTTP.get(url; headers=["Accept" => "application/json"])
    body = JSON3.read(String(resp.body))

    total_pages = body[:numPages]
    raw_recordings = body[:recordings]

    recordings = RecordingMeta[]
    for rec in raw_recordings
        try
            push!(recordings, parse_recording(rec))
        catch e
            @warn "Skipping recording: $e"
        end
    end

    (recordings, total_pages)
end

function _parse_duration(s::AbstractString)::Union{Float64,Nothing}
    isempty(s) && return nothing
    parts = split(s, ":")
    length(parts) == 2 || return nothing
    mins = tryparse(Float64, parts[1])
    secs = tryparse(Float64, parts[2])
    (mins === nothing || secs === nothing) && return nothing
    mins * 60.0 + secs
end

function parse_recording(data)::RecordingMeta
    lat_str = string(get(data, :lat, ""))
    lng_str = string(get(data, :lon, get(data, :lng, "")))
    lat = tryparse(Float64, lat_str)
    lng = tryparse(Float64, lng_str)
    coord = (lat !== nothing && lng !== nothing) ? GeoCoord(lng, lat) : nothing

    # Parse subspecies from the species name (ssp field) or empty
    subspecies = string(get(data, :ssp, ""))

    species = Species(
        genus = string(get(data, :gen, "")),
        species = string(get(data, :sp, "")),
        subspecies = subspecies,
        common_name = string(get(data, :en, "")),
    )

    # Parse date
    date_str = string(get(data, :date, ""))
    date = isempty(date_str) ? nothing : tryparse(Date, date_str)

    # Parse time
    time_str = string(get(data, :time, ""))
    rec_time = isempty(time_str) ? nothing : tryparse(Time, time_str)

    # Parse sample rate
    smp_str = string(get(data, :smp, ""))
    sample_rate = tryparse(Int, smp_str)

    RecordingMeta(
        source = XenoCanto,
        source_id = string(get(data, :id, "")),
        species = species,
        coord = coord,
        quality = parse_quality(string(get(data, :q, ""))),
        sound_type = parse_soundtype(string(get(data, :type, ""))),
        date = date,
        time = rec_time,
        country = string(get(data, :cnt, "")),
        location = string(get(data, :loc, "")),
        recordist = string(get(data, :rec, "")),
        license = string(get(data, :lic, "")),
        duration_s = _parse_duration(string(get(data, :length, ""))),
        sample_rate = sample_rate,
        remarks = string(get(data, :rmk, "")),
    )
end

function fetch_all_recordings(cfg::XenoCantoConfig, species::Species; max_pages::Union{Int,Nothing}=nothing)
    limiter = RateLimiter(cfg.request_delay)
    query = build_query(species, cfg)
    all_recordings = RecordingMeta[]
    page = 1
    total_pages = 1

    while page <= total_pages
        if max_pages !== nothing && page > max_pages
            break
        end

        throttle!(limiter)
        recordings, total_pages = fetch_page(cfg, limiter, query, page)
        append!(all_recordings, recordings)
        @info "Fetched page $page/$total_pages — $(length(recordings)) recordings"
        page += 1
    end

    all_recordings
end
