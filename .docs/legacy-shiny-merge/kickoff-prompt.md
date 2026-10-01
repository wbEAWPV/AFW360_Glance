# Kickoff prompt: Shiny app into 10-legacy-pipeline

Paste the text below into a new Claude Code session started in
`C:\Users\wb532966\eb-local\AFW360_Glance`.

---

You are implementing a planned change in the AFW 360 At A Glance repository
(`C:\Users\wb532966\eb-local\AFW360_Glance`, Windows, Git Bash and PowerShell available).

**Task.** Bring the Shiny for Python dashboard from branch `dev/app` into the folder
`10-legacy-pipeline/` on a new branch `dev/legacy-shiny` (cut from `dev/eb`), **next to**
the existing Quarto dashboard there, pointed at the frozen inputs in
`10-legacy-pipeline/data_raw/`, with its Posit Connect configuration so that a redeploy
from Positron updates the same Connect content
(`57e0a46b-db8d-4eeb-acca-994a67bfeb4c` on `https://w0lxdrconn01.worldbank.org`).

**Read first, in this order:**
1. `.docs/legacy-shiny-merge/plan.md`. This is the contract: decisions D1–D7, work
   packages WP0–WP8, and the facts already verified. Follow it. If something in the
   repository contradicts it, stop and report before improvising.
2. `CLAUDE.md` at the repository root.
3. `git show dev/app:CLAUDE.md` for the app's run commands and the Application Control
   note: never call `shiny.exe`, `rsconnect.exe` or `shinylive.exe`; always
   `python -m shiny`, `python -m pytest`,
   `python -c "from rsconnect.main import cli; cli()" ...`.

**Hard rules.**
- Never remove or break the Quarto dashboard (`10-legacy-pipeline/index.qmd`,
  `_quarto.yml`, `afw360/`, `content/`, `assets/`). The only change to it allowed is
  renaming its `requirements.txt` to `requirements-quarto.txt` (D2, after the gate check).
- Never edit, regenerate or add files under `data_raw/` (any `data_raw/`).
- Never edit `.posit/publish/deployments/deployment-OA6V.toml`.
- Never deploy, never push, never merge into `dev/eb`. Stop after WP8 and report.
- Do not touch the user's uncommitted work (for example `.docs/10-full-pipeline.qmd`):
  no `git add -A`, no `git add .`, no stash, no checkout of those paths. Stage
  explicit paths only.
- Commit after each work package on `dev/legacy-shiny`. End each commit message with
  the attribution line your session gives you.
- Log progress in `.docs/legacy-shiny-merge/PROGRESS.md` (create it in WP0): one entry
  per WP with what was done, the commit hash, the checks run and their results.

**How to work.** You may delegate mechanical edits to subagents (always pass an
explicit `model`: `opus` for implementation, `sonnet` for verification; never `fable`),
but you own the result: re-run the checks yourself before marking a WP done. Report
honestly: if a check was not run or failed, say so in `PROGRESS.md` and in your final
message, with the output.

**Done when:** WP0–WP8 in the plan are complete, the app's tests and the Quarto loader
tests pass (or failures are explained), the app serves `GET /` 200 from
`10-legacy-pipeline/`, a scratch copy of the bundle file list runs the app, the Quarto
page still renders in a scratch copy, `10-legacy-pipeline/DEPLOY.md` and the root
`CLAUDE.md` are updated, and your final message lists the commits, the results, and
the manual steps the user still has to do (plan section 6).
