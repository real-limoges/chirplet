# Reference

The part of the tree meant to be citable from code and commits, split by who wrote it.

- **`external/`** holds sources someone else wrote that the project cites: papers, specs, vendor docs, pinned citations.
  They are never edited; when a source is revised, the newer version replaces the file.
  It is empty for now.
- **`internal/`** holds what was written here about how the system fits together on `main`: [`architecture.md`](internal/architecture.md).
  These are state-of-things pages, rewritten in place as the code moves.

Nothing sits loose in this directory except this README.
A document here cites nothing elsewhere under `docs/`: it states the fact itself, and the rest of the tree cites it rather than the other way round.
Guides, walkthroughs and other generated material are not reference material.

This directory is the only committed part of `docs/`; everything else there is gitignored.
