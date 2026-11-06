# Chirplet

Chirplet renders the geographic emergence of song dialects in **White-crowned Sparrow** (*Zonotrichia leucophrys*) as a continuous, audible gradient field; boundaries are derived as regions where the song is changing fastest, not as discrete partitions.

## Components

This repo contains the Julia code for the offline pipeline and the Cloud Run prediction API: acquisition from xeno-canto, chirplet decomposition of audio into atoms, and a spatial model over atom distributions.
A separate web front end (most likely Phoenix LiveView) serves the UI and calls Chirplet over HTTP.

The work runs as five stages: acquisition, audio download, chirplet decomposition, spatial fit, and the prediction API.
Each stage has one exit criterion, and the next does not start until it is met.

## Status

Current milestone: **chirplet decomposition spike** (Stage 3).

- Acquisition pipeline: **functional**; metadata fetching from xeno-canto API v3 into SQLite
- Audio download: **functional**; full corpus downloaded (350 recordings), resumable
- Chirplet decomposition (DSP): **next**
- Spatial fit + gradient field: planned
- Cloud Run API service: planned

## Prerequisites

- Julia 1.12.4
- A xeno-canto API key (free; get one at https://xeno-canto.org/account)

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

Run from the repository root.
Paths, species, and filters come from `pipeline/config/default.toml`; `acquire.jl` takes one flag and `download.jl` takes none.

```bash
# Fetch metadata (1 page for a quick test)
julia --project=pipeline pipeline/scripts/acquire.jl --max-pages 1

# Fetch all metadata
julia --project=pipeline pipeline/scripts/acquire.jl

# Download audio for every stored recording not yet downloaded (resumable)
julia --project=pipeline pipeline/scripts/download.jl

# Run tests
julia --project=pipeline -e 'using Pkg; Pkg.test()'
```

To change the species, subspecies, country, or quality filter, edit the `[species]` and `[filtering]` sections of `pipeline/config/default.toml`.
