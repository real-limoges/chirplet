# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chirplet is a Julia package for acquiring and managing bird song recordings from xeno-canto. Currently focused on White-crowned Sparrow (*Zonotrichia leucophrys*) but configurable for other species. The project is in early development — many source files (`Chirplet.jl`, `pipeline.jl`) are stubs.

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

No `Project.toml` exists yet — one needs to be created before the package can be loaded or tested. Julia version is 1.12.4.

## Architecture

**Config layer** (`src/config.jl`, `config/default.toml`): `ChirpletConfig` is a `@kwdef` struct holding all settings — paths, API params, species targeting, quality filtering, download options. Config is loaded from TOML. The xeno-canto API key can also come from `XENOCANTO_API_KEY` env var.

**Type system** (`src/types.jl`): Domain types built on enums and structs:
- `QualityRating` (A–E) with ordering where A is best (lower Int = higher quality). `meets_quality` checks against a minimum.
- `SoundType`, `DataSource` enums
- `GeoCoord` value type, `RecordingMeta` / `Recording` entities (UUID-keyed)
- `RecordingFilter` for query-time filtering

**Storage** (`src/io/store.jl`): SQLite-backed recording store with a `recordings` table. Key operations: `open_store`, `close_store`, `count_recordings`, `query_recordings`.

**Acquisition** (`src/aquisition/client.jl`): xeno-canto API client with `RateLimiter` for respecting rate limits.

**Pipeline** (`src/pipeline.jl`): Stub for a stage-based pipeline system. `AcquisitionStage` is pushed onto a `Pipeline` and executed via `run_pipeline`.

**Entry point** (`scripts/acquire.jl`): CLI script that wires config → pipeline → store → summary stats.

## Conventions

- Note the typo in directory name: `src/aquisition/` (not `acquisition`)
- Quality ordering is inverted: `QA` has `Int` value 0 and is *best*, so `isless` uses `>` to sort A above E
- `RecordingFilter` is constructed from `ChirpletConfig` (forward declaration exists, implementation pending)
- Data stored under `data/` (raw, processed, cache, SQLite DB) — this directory is not committed
