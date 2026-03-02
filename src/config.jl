Base.@kwdef struct ChirpletConfig
    # Data Paths
    data_dir::String = joinpath(@__DIR__, "..", "data")
    raw_dir::String = joinpath(data_dir, "raw")
    processed_dir::String = joinpath(data_dir, "processed")
    cache_dir::String = joinpath(data_dir, "cache")
    db_path::String = joinpath(data_dir, "chirplet.sqlite")

    # Xeno-canto
    xc_base_url::String = "https://xeno-canto.org/api/2/recordings"
    xc_api_key::String = ""
    xc_rate_limit::Int = 1000
    xc_request_delay::Float64 = 3.6

    # Species
    target_genus::String = "Zonotrichia"
    target_species::String = "leucophrys"
    target_subspecies::String = ""
    target_country::String = ""

    # Quality
    min_quality::String = "C"
    require_coords = true
    sound_types::Vector{String} = ["song"]

    # Downloading Params
    max_concurrent = 4
    skip_existing::Bool = true
    audio_format::String = "mp3"

    log_level::String = "Info"
end