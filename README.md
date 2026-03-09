# Chirplet

A bird dialect visualization system, part of [Fugue](https://github.com/real-limoges). Maps geographic variation in bird song — starting with White-crowned Sparrow (*Zonotrichia leucophrys*) — by fitting generalized additive models to acoustic features and rendering dialect boundaries in the browser.

## Components

This monorepo contains:

- **`pipeline/`** — Julia data pipeline: acquires recordings from xeno-canto, extracts acoustic features, fits spatial GAMs, detects dialect boundaries
- **`gamlss-rs/`** — Rust GAMLSS library compiled to WASM for in-browser GAM prediction (planned)

A separate Phoenix application serves the web UI and calls the pipeline as an API service.

See `docs/architecture.md` for the full system design (local only, not committed).

## Status

- Acquisition pipeline: **functional** — metadata fetching from xeno-canto API v3 into SQLite
- Audio download + DSP: planned
- GAM fitting + boundary detection: planned
- gamlss-rs WASM: planned
- Phoenix integration: planned (separate repo)

## Prerequisites

- Julia 1.12.4
- A xeno-canto API key (free — get one at https://xeno-canto.org/account)

## Setup

```bash
cd pipeline
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Set your API key:

```bash
export XENOCANTO_API_KEY="your-key-here"
```

## Usage

```bash
# Fetch metadata (1 page for a quick test)
julia --project=pipeline pipeline/scripts/acquire.jl --max-pages 1

# Fetch all metadata
julia --project=pipeline pipeline/scripts/acquire.jl

# Download audio files too
julia --project=pipeline pipeline/scripts/acquire.jl --download

# Filter by subspecies / country
julia --project=pipeline pipeline/scripts/acquire.jl --subspecies nuttalli --country "United States"

# Run tests
julia --project=pipeline -e 'using Pkg; Pkg.test()'
```
