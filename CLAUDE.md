# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chirplet is a Julia package for acquiring and managing bird song recordings from xeno-canto. Currently focused on White-crowned Sparrow (*Zonotrichia leucophrys*) but configurable for other species. The project uses a 4-layer architecture separating domain logic, services, workflows, and CLI wiring.

## Development Commands

```bash
# Run the acquisition script (metadata only)
julia --project=. scripts/acquire.jl

# Download audio files too
julia --project=. scripts/acquire.jl --download

# Custom config / subspecies filtering
julia --project=. scripts/acquire.jl --config path.toml
julia --project=. scripts/acquire.jl --subspecies nuttalli --country "United States"

# Limit pages for testing
julia --project=. scripts/acquire.jl --max-pages 1
```

Requires a xeno-canto API key set via `XENOCANTO_API_KEY` env var. Julia version is 1.12.4.

## Architecture

Four layers with a strict dependency graph:

```
Domain  <--  Services  <--  scripts/ (CLI)
  ^                             |
  |                             v
  +--------- Workflows  <------+
```

- **Domain**: stdlib only (Dates, UUIDs)
- **Services**: Domain + IO packages (SQLite, HTTP, JSON3)
- **Workflows**: Domain only — IO is injected via function arguments
- **Scripts**: all three layers, wires them together

### Domain layer (`src/domain/`)

Pure domain types with no IO dependencies.

- `types.jl` — Enums (`QualityRating`, `SoundType`, `DataSource`), value types (`GeoCoord`, `Species`), entities (`RecordingMeta`, `Recording`). `RecordingMeta` has no url/audio_url fields; `Recording` uses `provenance::Dict{String,String}` for source-specific metadata.
- `filters.jl` — `RecordingFilter` @kwdef struct + `matches(filter, meta)::Bool` pure function.
- `domain.jl` — Module wrapper, exports all domain types.

### Services layer (`src/services/`)

IO-bound services that depend on Domain.

- `store/schema.jl` — `SCHEMA_SQL` constant with `provenance_json TEXT` column (no url/audio_url columns).
- `store/store.jl` — `StoreConfig` (just `db_path`), `Store` struct, `open_store`, `close_store`, `save_recording`, `count_recordings`, `query_recordings` (accepts `RecordingFilter` for SQL WHERE clauses).
- `aquisition/client.jl` — `XenoCantoConfig` struct, `RateLimiter`, xeno-canto API v3 client (`throttle!`, `build_query`, `fetch_page`, `parse_recording`, `fetch_all_recordings`).
- `services.jl` — Module wrapper using Domain + IO packages.

### Workflows layer (`src/workflows/`)

Pure orchestration with no IO imports. IO is injected via function arguments.

- `acquisition_workflow.jl` — `acquire_recordings(; fetch_page, save_recording, filter, species, max_pages)` with function injection. Returns `AcquisitionResult` summary struct.
- `workflows.jl` — Module wrapper using Domain only.

### Config (`src/config.jl`)

Just `load_toml(path) -> Dict`. No config struct — scripts read TOML and construct per-service configs directly.

### Entry point (`scripts/acquire.jl`)

CLI script that parses args, calls `load_toml`, constructs `StoreConfig`/`XenoCantoConfig`/`RecordingFilter`/`Species` from TOML sections, creates closures over service functions, and passes them to `acquire_recordings` workflow.

## Conventions

- Note the typo in directory name: `src/services/aquisition/` (not `acquisition`) — preserved intentionally
- Quality ordering is inverted: `QA` has `Int` value 0 and is *best*, so `isless` uses `>` to sort A above E
- `RecordingFilter` is constructed directly in scripts from TOML values (no config-struct constructor)
- Provenance (url, audio_url, etc.) stored as JSON in `provenance_json` column, not as separate columns
- Data stored under `data/` (raw, processed, cache, SQLite DB) — this directory is not committed
- xeno-canto API v3 requires an API key and tag-based queries (e.g., `gen:"Zonotrichia" sp:"leucophrys"`) — free-text queries from v2 no longer work
- v3 uses `lon` field instead of v2's `lng` for longitude
