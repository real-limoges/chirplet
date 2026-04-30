# Chirplet Architecture

Chirplet is part of [Fugue](https://github.com/real-limoges), a website about emergent things. This document describes how the pieces fit together: what runs where, where data lives, and which dependencies cross which boundaries. For *why* the design is the way it is — emergence framing, interaction shape, modeling commitments — see [`vision.md`](vision.md).

## System overview

```
┌─────────────────────────┐         ┌──────────────────────────┐
│   xeno-canto API v3     │         │    Browser (end user)    │
│  (recordings + audio)   │         │ ┌──────────────────────┐ │
└────────────┬────────────┘         │ │ Phoenix LiveView UI  │ │
             │ HTTPS                │ │  + map + audio       │ │
             ▼                      │ └──────────┬───────────┘ │
┌─────────────────────────┐         └────────────┼─────────────┘
│  Chirplet pipeline      │                      │ HTTPS / JSON
│  (Julia, offline)       │                      ▼
│                         │                ┌──────────────┐
│  acquire → chirplet     │                │  fugue-web   │
│  → spatial fit          │                │  (Phoenix)   │
│                         │                └──────┬───────┘
└────────────┬────────────┘                       │ HTTPS / JSON
             │ writes                             ▼
             ▼                          ┌──────────────────────┐
       ┌──────────┐    loads model      │  Chirplet API        │
       │  fitted  │ ◄────────────────── │  (Julia, this repo,  │
       │  model   │                     │  Cloud Run)          │
       └──────────┘                     └──────────────────────┘
```

Two artifacts ship from this repo: an offline pipeline that produces a fitted model, and a Cloud Run service that loads the model and answers prediction queries. Both are Julia.

Repositories involved:

| Repo | Language | Role |
|---|---|---|
| **chirplet** (this) | Julia | Acquisition, chirplet decomposition, spatial fitting; ships an offline pipeline + a Cloud Run prediction API |
| **fugue-web** (separate) | Elixir / Phoenix | Web UI; serves the map and audio playback, calls the Chirplet API |
| [**glissando**](https://github.com/real-limoges/glissando) | Rust | GAMLSS library. Sibling project, **not on Chirplet's critical path** — prediction is server-side in Julia |

Chirplet does not render UI or know about the map.

## The pipeline (`pipeline/`)

The Julia pipeline is organized as a four-layer system with a strict, one-directional dependency graph:

```
Domain  ◄──  Services  ◄──  scripts/ (CLI entry)
   ▲                            │
   │                            ▼
   └────────  Workflows  ◄─────┘
```

The point of the layering is to keep the parts that are easy to test (Domain, Workflows) free of IO, and to keep the parts that talk to the outside world (Services) isolated behind narrow interfaces.

### Domain — `pipeline/src/domain/`

Pure types and pure functions. Stdlib only (`Dates`, `UUIDs`). No SQLite, no HTTP, no JSON.

- **`types.jl`** — sum types (`QualityRating`, `SoundType`, `DataSource`), value types (`GeoCoord`, `Species`), and entities (`RecordingMeta`, `Recording`).
  - `RecordingMeta` carries source-agnostic recording metadata. Source-specific fields like xeno-canto URLs live in `Recording.provenance::Dict{String,String}` rather than as typed columns.
  - `QualityRating` ordering is inverted: `QA = 0` is the *best* rating, so `Base.isless` flips the comparison. `meets_quality(rating, minimum)` is the predicate to use rather than raw `<=`.
- **`filters.jl`** — `RecordingFilter` (`@kwdef` struct: `min_quality`, `require_coords`, `sound_types`, `country`, `subspecies`, `date_range`) and the pure predicate `matches(filter, meta) :: Bool`.

### Services — `pipeline/src/services/`

Stateful, IO-bound code. Wraps third-party packages (`SQLite.jl`, `HTTP.jl`, `JSON3.jl`) behind small, named interfaces so workflows can swap them out in tests.

- **`store/`** — SQLite persistence.
  - `schema.jl` defines a single `recordings` table with a `provenance_json TEXT` column (see "Provenance, not columns" below).
  - `store.jl` exposes `open_store`, `close_store`, `save_recording`, `count_recordings`, `query_recordings`. `query_recordings` accepts a `RecordingFilter` for in-DB filtering and returns a `DataFrame`.
- **`aquisition/`** *(directory name preserved with the typo)* — xeno-canto API v3 client.
  - `XenoCantoConfig` (base URL, API key, rate limit, request delay).
  - `RateLimiter` + `throttle!` enforce spacing between requests.
  - `build_query(species, cfg)` produces the v3 tag-based query string: `gen:"Zonotrichia" sp:"leucophrys" ssp:"nuttalli"`. Free-text v2-style queries do not work in v3.
  - `fetch_page(cfg, limiter, query, page)` returns `(Vector{RecordingMeta}, total_pages)`.

### Workflows — `pipeline/src/workflows/`

Orchestration. Imports Domain only; **all IO is injected as function arguments**.

```julia
acquire_recordings(;
    fetch_page,         # (species, page) -> (Vector{RecordingMeta}, total_pages)
    save_recording,     # (Recording) -> ()
    filter::RecordingFilter,
    species::Species,
    max_pages::Union{Int,Nothing} = nothing,
) -> AcquisitionResult
```

The workflow walks pages, applies the filter in-memory, and writes through the injected sink. In production the script wires `fetch_page` to the xeno-canto client and `save_recording` to the SQLite store; in tests you pass closures over fixtures and an in-memory store. The workflow itself never imports either.

### Scripts — `pipeline/scripts/`

The wiring layer. Reads TOML, constructs per-service configs, builds closures, and runs a workflow.

`acquire.jl` is currently the only entry point. It accepts `--download`, `--config <path>`, `--subspecies <name>`, `--country <name>`, and `--max-pages <N>`. After the run it prints a summary (totals, subspecies counts, quality counts, lat/lng range).

## Configuration

Configuration is plain TOML loaded with `load_toml(path) -> Dict{String,Any}` (`pipeline/src/config.jl`). There is no central config struct — `acquire.jl` reads each TOML section and constructs a per-service config (`StoreConfig`, `XenoCantoConfig`) and a `RecordingFilter` directly. Adding a new workflow means adding a new script that reads the sections it cares about; existing scripts do not need to change.

`pipeline/config/default.toml` ships with sensible defaults targeting White-crowned Sparrow, *nuttalli* subspecies, US-only, quality ≥ C, song only.

The xeno-canto API key is read from `XENOCANTO_API_KEY` first, then from `[api].xc_api_key` in the TOML. v3 requires a key on every request.

## Data layout

Everything written by the pipeline lives under `pipeline/data/` (gitignored):

```
pipeline/data/
├── chirplet.sqlite       # recordings table; one row per recording, idempotent on (source, source_id)
├── raw/                  # downloaded audio files, named by recording UUID
├── processed/            # DSP outputs (reserved)
└── cache/                # API response cache (reserved)
```

### Provenance, not columns

The `recordings` table stores source-agnostic metadata as typed columns and dumps everything source-specific (xeno-canto URLs, the `xc:` ID, license URLs, etc.) into a single `provenance_json TEXT` column. Adding a second source — Macaulay Library, eBird, a local archive — does not require a migration; it requires populating `Recording.provenance` with whatever keys make sense for that source.

This is also why the schema uses `lng` while the v3 API now uses `lon`: the column name is part of our internal contract, the API field name is mapped at the client boundary.

## DSP, modeling, and serving

The DSP layer is **chirplet decomposition**: each recording is decomposed into a bag of chirplet atoms (time × frequency × chirp-rate × duration × amplitude). Atoms are the feature primitive — there is no separate MFCC/mel-spectrogram step and no per-syllable segmentation. See [`vision.md`](vision.md) for the rationale.

The spatial model fits an atom distribution as a smooth function of (lat, lng). Boundaries are derived as regions of high gradient magnitude rather than fit directly; the model output is the gradient field itself, not a partition. Exact parameterization of the spatial model over atom distributions is open and will be settled after the chirplet decomposition spike.

Serving is a Julia HTTP service deployed to Cloud Run. The fitted model is loaded into the service at startup and answers prediction queries from `fugue-web`. Live re-fitting at request time is not in scope; refits are produced offline by the pipeline and the Cloud Run image is rebuilt or the model artifact swapped.

## Testing

`Pkg.test()` runs `pipeline/test/runtests.jl`, which is the standard Julia test driver. The Domain and Workflow layers are designed to be tested without IO — workflow tests pass closures for `fetch_page` and `save_recording` rather than touching the network or disk. Service-layer tests are integration tests against a temporary SQLite file and (for the xeno-canto client) recorded fixtures.

## CI

`.github/workflows/CI.yml` runs `julia-actions/julia-runtest` against Julia 1.12 on every push to `main` and every PR. `Manifest.toml` is gitignored, so dependencies are resolved on each run; cache hits depend on `Project.toml` being unchanged.
