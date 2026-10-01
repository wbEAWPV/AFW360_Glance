# Progress: Shiny app into `10-legacy-pipeline/`

Contract: `plan.md` next to this file. Branch `dev/legacy-shiny`, cut from `dev/eb` at `fd48ef8`.

## WP0. Set up (2026-10-01)

- `git status` was clean at the start (no user edits pending).
- Created `dev/legacy-shiny` from `dev/eb` (`fd48ef8`).
- D2 gate: searched the repository (excluding venvs, `_site/`, `site_libs/`, FMR runtime,
  agent worktrees) for `requirements.txt`. No `.github/` or root `.posit/` exists. Every hit
  is either `tools/verify/requirements.txt` (unrelated), the plan/kickoff for this work, or a
  historical record of the former *root* `requirements.txt` in `.docs/data-standard.qmd`,
  `.docs/sdmx-transition/plan.md` and `.docs/sdmx-transition/PROGRESS.md`. Nothing relies on
  `10-legacy-pipeline/requirements.txt` being the Quarto list. Gate passed.
- Side note for the user: `.gitattributes` has `requirements.txt text eol=lf`; the renamed
  `requirements-quarto.txt` no longer matches that rule (harmless on this machine, but a fresh
  checkout with `core.autocrlf=true` gives it CRLF). Also `data_raw/** -text` is anchored to the
  root, so it does not cover `10-legacy-pipeline/data_raw/`. Both left unchanged (not in plan).
- Commit: the WP0 commit adding this file (hash recorded in the WP1 entry).
