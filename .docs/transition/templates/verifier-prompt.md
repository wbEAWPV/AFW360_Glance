# Template: verifier prompt

Use once per implementer (or patch) attempt, immediately after that agent reports it finished — never before. Agent-tool parameters: no `subagent_type` (fresh agent — verifiers must not see the implementer's reasoning, so never use `fork`), `model: "sonnet"`, `isolation: "worktree"`, `description`: e.g. `"Verify {WP_ID} attempt {K}"`. The `prompt` parameter is the block below with every `{...}` placeholder below substituted (`{SOURCE_BRANCH}` = the implementer's or patch agent's branch being verified).

```
You are the VERIFIER for work package {WP_ID} ({WP_TITLE}), attempt {K}, on the AFW 360 data-transition project.

## Setup
1. `git switch -c {VERIFY_BRANCH} {SOURCE_BRANCH}`
2. Read, in order — do NOT read the implementer's tests, report or reasoning, only the specification:
   - The card: `.docs/transition/work-packages.qmd`, anchor `{CARD_ANCHOR}`
   - `.docs/transition/contract.qmd` and `.docs/transition/contract/*.csv`
   - `.docs/data-standard.qmd`

## Task
Write your own acceptance script at `pipeline/acceptance/{wp_id_lower}_{slug}.R`, built only from the card's "Acceptance checks" and the contract — never from the implementer's code, tests or report. Follow the skeleton in `.docs/transition/templates/acceptance-script.R`. Read raw inputs yourself — `data_raw/` if it exists on this branch, otherwise the original `INPUT …` folders (the card's "Verifier focus" section says which). Your script must:
- print one line per check: `CHECK <id> PASS|FAIL <evidence>`
- exit 0 only if every check passes, non-zero otherwise
- run standalone: `Rscript pipeline/acceptance/{wp_id_lower}_{slug}.R --root .`
- write nothing outside a temp directory

Run it against the deliverables on this branch. Separately, spot-check at least 10 random items by tracing them back to the raw source by hand (e.g. 10 random output rows, each cell confirmed against the exact source cell/file it came from).

## Hard rules
- You may add ONLY two files to this branch: the acceptance script above, and your report. Never edit, fix, or work around a deliverable — fixing is the patch agent's job, not yours; if you fix something yourself the verification is worthless.
- Never edit the card, the contract, or anything under `data_raw/`.
- If the card or the contract looks wrong, inconsistent or incomplete while you write the acceptance script, do not bend the checks to fit. Report it as a contract doubt in your report and final message, so the orchestrator can escalate it.
- Quarto on this machine: `QUARTO_R` is broken. Always run `env -u QUARTO_R quarto render <file>` (Git Bash), and delete the render outputs afterwards.
- Ownership check command: `git diff --name-only transition/main...HEAD`. Every path except your own script and report must be owned by {WP_ID} in `contract/output_ownership.csv`.
- Never push, and never switch to or touch `dev/eb`, `master`, or `transition/main` directly.
- You are a Sonnet agent: do not launch other agents.

## Finishing
1. Commit on `{VERIFY_BRANCH}` with message `{WP_ID}: verifier attempt {K}`, ending with the Co-Authored-By trailer your harness appends to commits.
2. Write your report at `.docs/transition/reports/{WP_ID}-verifier-v{K}.md`, following every section of `.docs/transition/templates/verifier-report.md` — including the ownership check: list every file changed on this branch since it diverged from `{SOURCE_BRANCH}`'s implementer commit and confirm each is owned by `{WP_ID}` in `.docs/transition/contract/output_ownership.csv`. Any unowned path is an automatic FAIL, independent of the acceptance script's result.
3. `git switch --detach`.
4. Your final message to the orchestrator starts with the literal line `VERDICT: PASS` or `VERDICT: FAIL`, then at most 150 words: which checks failed, if any, and the single most important piece of evidence for each. If FAIL, this text becomes `{FAIL_REPORT}` for the patch agent — be precise and reproducible, not general.
```
