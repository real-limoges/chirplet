# Chirplet

A Julia package for acquiring and managing bird song recordings from [xeno-canto](https://xeno-canto.org). Currently focused on White-crowned Sparrow (*Zonotrichia leucophrys*) but configurable for other species.

## Status

Early development. The 4-layer architecture (Domain, Services, Workflows, CLI) is in place. Domain types, SQLite store, and the acquisition workflow are implemented. The xeno-canto API client functions (`fetch_page`, `parse_recording`, `fetch_all_recordings`) are stubbed out — completing them will make end-to-end acquisition work.

## Prerequisites

- Julia 1.12.4

## Setup

No `Project.toml` exists yet. Create one from the Julia REPL:

```julia
# $ julia --project=.
using Pkg
Pkg.add(["HTTP", "JSON3", "SQLite", "DataFrames", "DBInterface", "UUIDs", "Dates", "TOML"])
```

Then on subsequent sessions:

```bash
julia --project=.
# julia> using Pkg; Pkg.instantiate()
```

## Usage

```bash
# Fetch metadata only (once API client stubs are implemented)
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
│   │       └── client.jl               # XenoCantoConfig, RateLimiter, API stubs
│   └── workflows/
│       ├── workflows.jl                 # Workflows module (uses Domain only)
│       └── acquisition_workflow.jl      # acquire_recordings() with function injection
├── docs/
│   └── guide.md                         # implementation tutorial
└── CLAUDE.md
```

## Documentation

See [`docs/guide.md`](docs/guide.md) for a detailed implementation guide.
