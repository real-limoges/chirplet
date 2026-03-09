Base.@kwdef struct StoreConfig
    db_path::String
end

struct Store
    db::SQLite.DB
    path::String
end

function open_store(cfg::StoreConfig)
    db = SQLite.DB(cfg.db_path)
    DBInterface.execute(db, SCHEMA_SQL)
    Store(db, cfg.db_path)
end

function close_store(store::Store)
    DBInterface.close!(store.db)
end

function save_recording(store::Store, rec::Recording)
    m = rec.meta
    sql = """
    INSERT OR IGNORE INTO recordings
        (id, source, source_id, genus, species, subspecies, common_name,
         lat, lng, elev_m, quality, sound_type, date, time,
         country, location, recordist, license,
         duration_s, sample_rate, remarks, provenance_json,
         audio_path, downloaded, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?)
    """

    coord_lat = m.coord !== nothing ? m.coord.lat : missing
    coord_lng = m.coord !== nothing ? m.coord.lng : missing
    coord_elev = m.coord !== nothing ? m.coord.elevation : missing

    DBInterface.execute(store.db, sql, [
        string(rec.id),
        string(m.source),
        m.source_id,
        m.species.genus,
        m.species.species,
        m.species.subspecies,
        m.species.common_name,
        coord_lat,
        coord_lng,
        coord_elev,
        string(m.quality),
        string(m.sound_type),
        m.date !== nothing ? string(m.date) : missing,
        m.time !== nothing ? string(m.time) : missing,
        m.country,
        m.location,
        m.recordist,
        m.license,
        m.duration_s !== nothing ? m.duration_s : missing,
        m.sample_rate !== nothing ? m.sample_rate : missing,
        m.remarks,
        JSON3.write(rec.provenance),
        rec.audio_path !== nothing ? rec.audio_path : missing,
        rec.downloaded ? 1 : 0,
        string(rec.created_at),
    ])
end

function count_recordings(store::Store)
    result = DBInterface.execute(store.db, "SELECT COUNT(*) AS n FROM recordings")
    first(result).n
end

function query_recordings(store::Store; filter::Union{RecordingFilter,Nothing}=nothing)
    conditions = String[]
    params = Any[]

    if filter !== nothing
        if filter.require_coords
            push!(conditions, "lat IS NOT NULL AND lng IS NOT NULL")
        end
        if !isempty(filter.country)
            push!(conditions, "country = ?")
            push!(params, filter.country)
        end
        if !isempty(filter.subspecies)
            push!(conditions, "subspecies = ?")
            push!(params, filter.subspecies)
        end
        push!(conditions, "quality IN (" * join(["?" for _ in 1:Int(filter.min_quality)+1], ", ") * ")")
        for q in 0:Int(filter.min_quality)
            push!(params, string(QualityRating(q)))
        end
        if !isempty(filter.sound_types)
            push!(conditions, "sound_type IN (" * join(["?" for _ in filter.sound_types], ", ") * ")")
            for st in filter.sound_types
                push!(params, string(st))
            end
        end
        if filter.date_range !== nothing
            lo, hi = filter.date_range
            push!(conditions, "date >= ? AND date <= ?")
            push!(params, string(lo))
            push!(params, string(hi))
        end
    end

    sql = "SELECT * FROM recordings"
    if !isempty(conditions)
        sql *= " WHERE " * join(conditions, " AND ")
    end

    DBInterface.execute(store.db, sql, params) |> DataFrame
end
