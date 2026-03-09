# Chirplet

A Julia package for acquiring and managing bird song recordings from [xeno-canto](https://xeno-canto.org). Currently focused on White-crowned Sparrow (*Zonotrichia leucophrys*) but configurable for other species.

## Status

The acquisition pipeline is fully functional. The 4-layer architecture (Domain, Services, Workflows, CLI) is complete, with end-to-end metadata fetching from the xeno-canto API v3 into SQLite.

## Prerequisites

- Julia 1.12.4
- A xeno-canto API key (free — get one at https://xeno-canto.org/account)

## Setup

```bash
julia --project=.
# julia> using Pkg; Pkg.instantiate()
```

Set your API key:

```bash
export XENOCANTO_API_KEY="your-key-here"
```

## Usage

```bash
# Fetch metadata (1 page for a quick test)
julia --project=. scripts/acquire.jl --max-pages 1

# Fetch all metadata
julia --project=. scripts/acquire.jl

# Download audio files too
julia --project=. scripts/acquire.jl --download

# Custom config / subspecies filtering
julia --project=. scripts/acquire.jl --config path.toml
julia --project=. scripts/acquire.jl --subspecies nuttalli --country "United States"

# Limit pages for testing
julia --project=. scripts/acquire.jl --max-pages 1
```

## Architecture

Four layers with a strict dependency graph:

```
Domain  <--  Services  <--  scripts/ (CLI)
  ^                             |
  |                             v
  +--------- Workflows  <------+
```

- **Domain** — Pure types and filter logic (stdlib only)
- **Services** — Store (SQLite) and API client (xeno-canto), with per-service config structs
- **Workflows** — Orchestration with IO injected via function arguments
- **Scripts** — CLI entry point, wires all layers together

## File Tree

```
Chirplet/
├── config/
│   └── default.toml                     # settings (complete)
├── scripts/
│   └── acquire.jl                       # CLI entry point (complete)
├── src/
│   ├── Chirplet.jl                      # module root, wires submodules
│   ├── config.jl                        # load_toml() utility
│   ├── domain/
│   │   ├── domain.jl                    # Domain module (stdlib only)
│   │   ├── types.jl                     # enums, value types, entities
│   │   └── filters.jl                   # RecordingFilter + matches()
│   ├── services/
│   │   ├── services.jl                  # Services module (uses Domain + IO)
│   │   ├── store/
│   │   │   ├── schema.jl               # SCHEMA_SQL constant
│   │   │   └── store.jl                # StoreConfig, Store, CRUD functions
│   │   └── aquisition/
│   │       └── client.jl               # XenoCantoConfig, RateLimiter, xeno-canto v3 client
│   └── workflows/
│       ├── workflows.jl                 # Workflows module (uses Domain only)
│       └── acquisition_workflow.jl      # acquire_recordings() with function injection
└── CLAUDE.md
```

## Running Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```
