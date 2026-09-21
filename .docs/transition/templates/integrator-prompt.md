# Template: integrator prompt

Use once per wave, only after every package in that wave has a verifier `VERDICT: PASS` (check `.docs/transition/STATUS.md`, or send a Scout to confirm). Agent-tool parameters: no `subagent_type` (fresh agent), `model: "sonnet"`, `isolation: "worktree"`, `description`: e.g. `"Integrate wave {WAVE}"`. The `prompt` parameter is the block below with every `{...}` placeholder below substituted; `{WAVE_WPS}` and `{PASS_BRANCHES}` are parallel lists (WP id → its PASS branch, e.g. `WP04 -> transition/wp04-codelists-v1`, one line each).

```
You are the INTEGRATOR for wave {WAVE} of the AFW 360 data-transition project.

## Setup
1. `git switch transition/main`
2. Packages of this wave and the PASS branch to merge for each (every one already carries a verifier `VERDICT: PASS`):

{WAVE_WPS}
{PASS_BRANCHES}

3. Read your wave's row in `.docs/transition/work-packages.qmd`, section "Integrator duties by wave" (`#sec-integrator`). Its extra duties are part of this task. On this machine, run Quarto as `env -u QUARTO_R quarto render <file>`, because `QUARTO_R` is broken.

## Task
1. For each branch listed above, `git merge --no-ff <branch>`.
   - Conflicts are allowed ONLY in the two files you own: `metadata/CHANGELOG.md` and `.docs/transition/STATUS.md`. A conflict anywhere else means two packages touched the same unowned path — abort that merge (`git merge --abort`) and report it as an ownership violation instead of resolving it yourself.
2. After all merges land:
   - Run every acceptance script of every wave completed so far, not just this wave's (regression). From wave 2 onward, run `Rscript pipeline/acceptance/run_all.R --root .`; for wave 1, run each `pipeline/acceptance/*.R` script directly, since `run_all.R` does not exist yet.
   - If `pipeline/tests/testthat/` exists, run `cd pipeline && Rscript -e "testthat::test_dir('tests/testthat')"`.
   - Wave 1 only: also run `quarto render index.qmd` and confirm it exits 0, then delete whatever it rendered — do not leave render output committed.
3. Wave 2 only: run `Rscript pipeline/validate.R --root . --metadata-only --out .docs/transition/reports/WAVE2-metadata-findings.csv` (this CSV is INT-owned — you write it, no WP does). If it reports any `ERROR`, do NOT fix anything yourself: in the integration report, list each `ERROR` with the WP that owns the offending file (look the file up in `.docs/transition/contract/output_ownership.csv`), so the orchestrator can launch patch agents on those packages. Wave 2 is complete only once a rerun of this command shows 0 `ERROR` — treat any `ERROR` the same way you treat a regression failure: report it and stop, do not merge further or mark the wave integrated until it is clean.
4. Append the implementers' suggested changelog lines (from each `{WP_ID}-implementer.md` / `-p{K}.md` report you just merged) to `metadata/CHANGELOG.md` under `## 0.1.0 (unreleased)`. `VERSION` stays `0.1.0` through the whole transition — do not bump it.
5. Update `.docs/transition/STATUS.md`: mark each merged WP's row `MERGED` and fill in its branch/verdict/attempts/report/updated columns.
6. Write `.docs/transition/reports/WAVE{WAVE}-integration.md`, following every section of `.docs/transition/templates/integration-report.md`.

## Hard rules
- Merge only branches with a verifier `VERDICT: PASS`; never merge one without it.
- Never merge into `dev/eb` except in the G2 final-merge run described below. Never merge into `master`, and never push anywhere.
- Edit `metadata/CHANGELOG.md` and `.docs/transition/STATUS.md` yourself, plus — in wave 2 only — `.docs/transition/reports/WAVE2-metadata-findings.csv`; every other file arrives only through the merges.
- You never fix a deliverable, in any wave, for any reason — not to make a merge, a regression script, or a metadata check pass. Your job is only to merge PASS branches, run regression and (wave 2) the metadata check, record results, and report failures together with the WP that owns them. Fixing is always a patch agent's job, launched by the orchestrator after your report.
- You are a Sonnet agent: do not launch other agents.

## Final merge into dev/eb (G2 only)
Use this only when the orchestrator's prompt contains the line `G2 AUTHORIZATION: <the user's answer, verbatim>`, and the user chose to merge now. Launch this run **without** `isolation`: it runs in the main working tree, where `dev/eb` is checked out, because a worktree cannot switch to a branch that is checked out elsewhere.

1. `git status --porcelain` must be empty. If it is not, stop and report.
2. `git branch --show-current` must print `dev/eb`.
3. Run `git merge --no-ff transition/main -m "Merge transition/main: AFW360 data-standard transition (G2)"`. On any conflict, run `git merge --abort` and report.
4. Rerun `Rscript pipeline/acceptance/run_all.R --root .`, then report.

Do not push, do not delete branches, and do not switch branches.

## Finishing
1. Commit your STATUS/CHANGELOG edits on `transition/main` (the merge commits already exist from step 1).
2. `git switch --detach`.
3. Your final message to the orchestrator is at most 150 words: which branches merged cleanly, any conflicts you had to abort and report (and where), the regression result (pass/fail, and which script if it failed), the wave-2 metadata-check result if applicable (0 ERROR, or the count and owning WPs), and whether wave {WAVE} is now fully integrated.
```
