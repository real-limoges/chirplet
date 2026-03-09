using Test
using Chirplet
using Dates

@testset "Chirplet" begin

    @testset "QualityRating" begin
        @test parse_quality("A") == QA
        @test parse_quality("b") == QB
        @test parse_quality(" C ") == QC
        @test parse_quality("xyz") == QUnknown

        # QA (0) is best, so QA > QB in domain ordering
        @test QA > QB
        @test QB > QC

        @test meets_quality(QA, QC) == true
        @test meets_quality(QC, QC) == true
        @test meets_quality(QD, QC) == false
    end

    @testset "SoundType" begin
        @test parse_soundtype("song") == Song
        @test parse_soundtype("Song") == Song
        @test parse_soundtype("call notes") == Call
        @test parse_soundtype("alarm") == Alarm
        @test parse_soundtype("flight") == Flight
        @test parse_soundtype("drumming") == Drumming
        @test parse_soundtype("dawn") == Dawn
        @test parse_soundtype("unknown") == Other
    end

    @testset "GeoCoord" begin
        g = GeoCoord(-122.0, 37.0)
        @test g.lng == -122.0
        @test g.lat == 37.0
        @test g.elevation === nothing
        @test isvalid(g)

        g2 = GeoCoord(0.0, 91.0, nothing)
        @test !isvalid(g2)

        g3 = GeoCoord(181.0, 0.0, nothing)
        @test !isvalid(g3)
    end

    @testset "Species" begin
        sp = Species(genus="Zonotrichia", species="leucophrys",
                     subspecies="nuttalli", common_name="White-crowned Sparrow")
        @test sp.genus == "Zonotrichia"
        @test sp.subspecies == "nuttalli"

        sp2 = Species(genus="Zonotrichia", species="leucophrys")
        @test sp2.subspecies == ""
        @test sp2.common_name == ""
    end

    @testset "RecordingMeta & Recording" begin
        sp = Species(genus="Zonotrichia", species="leucophrys")
        meta = RecordingMeta(
            source=XenoCanto,
            source_id="12345",
            species=sp,
            coord=GeoCoord(-122.0, 37.0),
            quality=QA,
            sound_type=Song,
        )
        @test meta.source == XenoCanto
        @test meta.country == ""

        rec = Recording(meta; provenance=Dict("url" => "https://example.com"))
        @test rec.meta === meta
        @test rec.provenance["url"] == "https://example.com"
        @test rec.downloaded == false
    end

    @testset "RecordingFilter / matches" begin
        sp = Species(genus="Zonotrichia", species="leucophrys", subspecies="nuttalli")

        good_meta = RecordingMeta(
            source=XenoCanto, source_id="1", species=sp,
            coord=GeoCoord(-122.0, 37.0), quality=QA, sound_type=Song,
            country="United States",
        )

        filter = RecordingFilter(
            min_quality=QC,
            require_coords=true,
            sound_types=[Song],
            country="United States",
            subspecies="nuttalli",
        )

        @test matches(filter, good_meta) == true

        # Fails quality
        bad_quality = RecordingMeta(
            source=XenoCanto, source_id="2", species=sp,
            coord=GeoCoord(0.0, 0.0), quality=QD, sound_type=Song,
            country="United States",
        )
        @test matches(filter, bad_quality) == false

        # Fails coords
        no_coords = RecordingMeta(
            source=XenoCanto, source_id="3", species=sp,
            quality=QA, sound_type=Song, country="United States",
        )
        @test matches(filter, no_coords) == false

        # Fails sound type
        wrong_type = RecordingMeta(
            source=XenoCanto, source_id="4", species=sp,
            coord=GeoCoord(0.0, 0.0), quality=QA, sound_type=Call,
            country="United States",
        )
        @test matches(filter, wrong_type) == false

        # Fails country
        wrong_country = RecordingMeta(
            source=XenoCanto, source_id="5", species=sp,
            coord=GeoCoord(0.0, 0.0), quality=QA, sound_type=Song,
            country="Mexico",
        )
        @test matches(filter, wrong_country) == false

        # Fails subspecies
        sp2 = Species(genus="Zonotrichia", species="leucophrys", subspecies="gambelii")
        wrong_sub = RecordingMeta(
            source=XenoCanto, source_id="6", species=sp2,
            coord=GeoCoord(0.0, 0.0), quality=QA, sound_type=Song,
            country="United States",
        )
        @test matches(filter, wrong_sub) == false

        # Date range filtering
        filter_dates = RecordingFilter(
            min_quality=QE,
            require_coords=false,
            sound_types=[Song, Call],
            date_range=(Date(2020, 1, 1), Date(2020, 12, 31)),
        )
        in_range = RecordingMeta(
            source=XenoCanto, source_id="7", species=sp,
            quality=QA, sound_type=Song, date=Date(2020, 6, 15),
        )
        @test matches(filter_dates, in_range) == true

        out_range = RecordingMeta(
            source=XenoCanto, source_id="8", species=sp,
            quality=QA, sound_type=Song, date=Date(2019, 6, 15),
        )
        @test matches(filter_dates, out_range) == false
    end

    @testset "acquire_recordings workflow" begin
        sp = Species(genus="Zonotrichia", species="leucophrys", subspecies="nuttalli")

        # Mock data: 2 pages, 3 recordings each
        page1 = [
            RecordingMeta(source=XenoCanto, source_id="1", species=sp,
                coord=GeoCoord(0.0, 0.0), quality=QA, sound_type=Song),
            RecordingMeta(source=XenoCanto, source_id="2", species=sp,
                coord=GeoCoord(0.0, 0.0), quality=QD, sound_type=Song),  # fails quality
            RecordingMeta(source=XenoCanto, source_id="3", species=sp,
                coord=GeoCoord(0.0, 0.0), quality=QB, sound_type=Call),  # fails sound_type
        ]
        page2 = [
            RecordingMeta(source=XenoCanto, source_id="4", species=sp,
                coord=GeoCoord(0.0, 0.0), quality=QB, sound_type=Song),
        ]

        pages = Dict(1 => page1, 2 => page2)
        saved = Recording[]

        mock_fetch = (species, page) -> (get(pages, page, RecordingMeta[]), 2)
        mock_save = (rec) -> push!(saved, rec)

        filter = RecordingFilter(min_quality=QC, sound_types=[Song])

        result = acquire_recordings(
            fetch_page=mock_fetch,
            save_recording=mock_save,
            filter=filter,
            species=sp,
        )

        @test result.total_fetched == 4
        @test result.total_matched == 2
        @test result.total_saved == 2
        @test result.pages_fetched == 2
        @test length(saved) == 2

        # Test max_pages limit
        saved2 = Recording[]
        result2 = acquire_recordings(
            fetch_page=mock_fetch,
            save_recording=(rec) -> push!(saved2, rec),
            filter=filter,
            species=sp,
            max_pages=1,
        )
        @test result2.pages_fetched == 1
        @test result2.total_fetched == 3
        @test length(saved2) == 1
    end

    @testset "Store round-trip" begin
        db_path = tempname() * ".sqlite"
        try
            store = open_store(StoreConfig(db_path=db_path))
            @test count_recordings(store) == 0

            sp = Species(genus="Zonotrichia", species="leucophrys")
            meta = RecordingMeta(
                source=XenoCanto, source_id="XC123", species=sp,
                coord=GeoCoord(-122.0, 37.0), quality=QA, sound_type=Song,
                country="United States", recordist="Test",
            )
            rec = Recording(meta; provenance=Dict("url" => "https://example.com/XC123"))
            save_recording(store, rec)

            @test count_recordings(store) == 1

            df = query_recordings(store)
            @test size(df, 1) == 1
            @test df.source_id[1] == "XC123"

            # Filtered query
            filter = RecordingFilter(min_quality=QC, sound_types=[Song], country="United States")
            df2 = query_recordings(store; filter=filter)
            @test size(df2, 1) == 1

            # Filter that excludes
            filter_none = RecordingFilter(min_quality=QC, sound_types=[Call])
            df3 = query_recordings(store; filter=filter_none)
            @test size(df3, 1) == 0

            close_store(store)
        finally
            rm(db_path; force=true)
        end
    end

    @testset "throttle!" begin
        limiter = RateLimiter(0.1)

        # First call should not delay (last_request is 0.0)
        t0 = time()
        throttle!(limiter)
        @test time() - t0 < 0.05

        # Second call should delay ~0.1s
        t1 = time()
        throttle!(limiter)
        elapsed = time() - t1
        @test elapsed >= 0.08  # allow small tolerance

        # After waiting long enough, no delay
        sleep(0.15)
        t2 = time()
        throttle!(limiter)
        @test time() - t2 < 0.05
    end

    @testset "build_query" begin
        cfg = XenoCantoConfig()
        sp = Species(genus="Zonotrichia", species="leucophrys")
        q = build_query(sp, cfg)
        @test q == "gen:\"Zonotrichia\" sp:\"leucophrys\""

        sp2 = Species(genus="Melospiza", species="melodia", subspecies="melodia")
        q2 = build_query(sp2, cfg)
        @test q2 == "gen:\"Melospiza\" sp:\"melodia\" ssp:\"melodia\""

        # No subspecies → no ssp tag
        sp3 = Species(genus="Melospiza", species="melodia")
        q3 = build_query(sp3, cfg)
        @test !contains(q3, "ssp:")
    end

    @testset "load_toml" begin
        path = tempname() * ".toml"
        try
            write(path, """
            [species]
            genus = "Zonotrichia"
            species = "leucophrys"
            """)
            cfg = load_toml(path)
            @test cfg["species"]["genus"] == "Zonotrichia"
        finally
            rm(path; force=true)
        end
    end

end
