# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chirplet is a bird dialect visualization system, part of the Fugue umbrella. It maps geographic variation in bird song by fitting GAMs to acoustic features and rendering dialect boundaries in the browser.

This is a monorepo containing:
- **`pipeline/`** — Julia data pipeline (acquisition, DSP, feature extraction, GAM fitting)
- **`gamlss-rs/`** — Rust GAMLSS library compiled to WASM for in-browser GAM prediction (to be added)

A separate Phoenix application (not in this repo) serves the web UI and calls the Chirplet pipeline as an API service.

See `docs/architecture.md` for the full system design (local only, gitignored).

## Development Commands

### Julia Pipeline

```bash
# Run the acquisition script (metadata only)
julia --project=pipeline pipeline/scripts/acquire.jl

# Download audio files too
julia --project=pipeline pipeline/scripts/acquire.jl --download

# Custom config / subspecies filtering
julia --project=pipeline pipeline/scripts/acquire.jl --config path.toml
julia --project=pipeline pipeline/scripts/acquire.jl --subspecies nuttalli --country "United States"

# Limit pages for testing
julia --project=pipeline pipeline/scripts/acquire.jl --max-pages 1

# Run tests
julia --project=pipeline -e 'using Pkg; Pkg.test()'
```

Requires a xeno-canto API key set via `XENOCANTO_API_KEY` env var. Julia version is 1.12.4.

## Repo Layout

```
chirplet/
├── pipeline/                # Julia data pipeline
│   ├── src/
│   │   ├── Chirplet.jl      # module root
│   │   ├── config.jl        # load_toml() utility
│   │   ├── domain/          # pure types, filters (stdlib only)
│   │   ├── services/        # IO-bound services (SQLite, HTTP, JSON3)
│   │   └── workflows/       # orchestration with injected IO
│   ├── scripts/
│   │   └── acquire.jl       # CLI entry point
│   ├── config/
│   │   └── default.toml     # default settings
│   ├── test/
│   ├── data/                # .gitignored
│   ├── Project.toml
│   └── Manifest.toml        # .gitignored
├── gamlss-rs/               # Rust GAMLSS library (planned)
├── docs/
│   └── architecture.md      # full system design
├── .github/workflows/       # CI
├── CLAUDE.md
└── README.md
```

## Pipeline Architecture

Four layers with a strict dependency graph:

```
Domain  <--  Services  <--  scripts/ (CLI)
  ^                             |
  |                             v
  +--------- Workflows  <------+
```

- **Domain** (`pipeline/src/domain/`): stdlib only (Dates, UUIDs). Pure types and filter logic.
  - `types.jl` — Enums (`QualityRating`, `SoundType`, `DataSource`), value types (`GeoCoord`, `Species`), entities (`RecordingMeta`, `Recording`). `RecordingMeta` has no url/audio_url fields; `Recording` uses `provenance::Dict{String,String}` for source-specific metadata.
  - `filters.jl` — `RecordingFilter` @kwdef struct + `matches(filter, meta)::Bool` pure function.
  - `domain.jl` — Module wrapper, exports all domain types.

- **Services** (`pipeline/src/services/`): Domain + IO packages (SQLite, HTTP, JSON3).
  - `store/schema.jl` — `SCHEMA_SQL` constant with `provenance_json TEXT` column (no url/audio_url columns).
  - `store/store.jl` — `StoreConfig`, `Store`, `open_store`, `close_store`, `save_recording`, `count_recordings`, `query_recordings`.
  - `aquisition/client.jl` — `XenoCantoConfig`, `RateLimiter`, xeno-canto API v3 client.
  - `services.jl` — Module wrapper using Domain + IO packages.

- **Workflows** (`pipeline/src/workflows/`): Domain only — IO is injected via function arguments.
  - `acquisition_workflow.jl` — `acquire_recordings(; fetch_page, save_recording, filter, species, max_pages)` with function injection. Returns `AcquisitionResult`.
  - `workflows.jl` — Module wrapper using Domain only.

- **Scripts** (`pipeline/scripts/`): all three layers, wires them together.

### Config (`pipeline/src/config.jl`)

Just `load_toml(path) -> Dict`. No config struct — scripts read TOML and construct per-service configs directly.

## Conventions

- Note the typo in directory name: `pipeline/src/services/aquisition/` (not `acquisition`) — preserved intentionally
- Quality ordering is inverted: `QA` has `Int` value 0 and is *best*, so `isless` uses `>` to sort A above E
- `RecordingFilter` is constructed directly in scripts from TOML values (no config-struct constructor)
- Provenance (url, audio_url, etc.) stored as JSON in `provenance_json` column, not as separate columns
- Data stored under `pipeline/data/` (raw, processed, cache, SQLite DB) — this directory is not committed
- xeno-canto API v3 requires an API key and tag-based queries (e.g., `gen:"Zonotrichia" sp:"leucophrys"`) — free-text queries from v2 no longer work
- v3 uses `lon` field instead of v2's `lng` for longitude
