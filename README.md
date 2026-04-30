# Chirplet

A panel of [Fugue](https://github.com/real-limoges), a website about emergent things. Chirplet renders the geographic emergence of song dialects in **White-crowned Sparrow** (*Zonotrichia leucophrys*) as a continuous, audible gradient field — boundaries are derived as regions where the song is changing fastest, not as discrete partitions.

## Components

This repo contains the Julia code for the offline pipeline and the Cloud Run prediction API: acquisition from xeno-canto, chirplet decomposition of audio into atoms, and a spatial model over atom distributions. A separate Phoenix application ([fugue-web](https://github.com/real-limoges)) serves the web UI and calls Chirplet over HTTP.

See [`docs/vision.md`](docs/vision.md) for the design intent and [`docs/architecture.md`](docs/architecture.md) for the system design.

## Status

- Acquisition pipeline: **functional** — metadata fetching from xeno-canto API v3 into SQLite
- Audio download: scaffolded; not yet exercised at scale
- Chirplet decomposition (DSP): planned
- Spatial fit + gradient field: planned
- Cloud Run API service: planned

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
