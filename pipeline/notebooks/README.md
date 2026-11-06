# Notebooks

Jupyter notebooks (`.ipynb`) for exploration.
Not production code: once a function in here proves itself, lift it into `pipeline/src/` and let Revise pick it up.

## First-Time Setup

Install the IJulia kernel against the pipeline project:

```bash
julia --project=pipeline -e 'using Pkg; Pkg.add("IJulia")'
```

## Run in VS Code

1. Open the `.ipynb` file.
2. Top-right kernel picker → **Julia 1.12** (or whichever version is on `pipeline/Project.toml`).
3. Run cells with `shift+enter`.

The Julia VS Code extension (publisher: `julialang`) gives you LSP, REPL, plot pane, and notebook kernel.

## What's Here

- `decomposition_spike.ipynb`: Stage 3 (chirplet decomposition) of the pipeline.
  Pick a WAV, plot spectrogram, run decomposition, overlay atoms, resynthesize, listen.
  Exit gate is *audibly recognizable resynthesis*.

## Notes

- Audio plays inline via a base64-embedded `<audio>` tag, which works in both VS Code and browser Jupyter, no temp files.
- MP3 reading isn't wired up yet, and the corpus is mostly MP3 (324 of 350 files).
  The chosen path is shelling out to `ffmpeg` to decode to PCM: no Julia dependency to vet, and it also reads the two corpus WAVs that WAV.jl rejects.
  ffmpeg is needed wherever the pipeline runs, not in the Cloud Run image, which serves a fitted model and decodes no audio.
  Convert to WAV by hand if you just need one recording to experiment with.
