# Template: implementer prompt

Use once per work package, when its "Depends on" packages are already merged into `transition/main` (check `.docs/transition/STATUS.md`, or send a Scout to check). Launch all packages of a wave in one message, one implementer each. Agent-tool parameters: no `subagent_type` (fresh general-purpose agent — do not use `fork`), `model: "sonnet"`, `isolation: "worktree"`, `description`: e.g. `"Implement {WP_ID}"`. The `prompt` parameter is the block below with every `{...}` placeholder below substituted.

```
You are the IMPLEMENTER for work package {WP_ID} ({WP_TITLE}), wave {WAVE}, on the AFW 360 data-transition project (repo: AFW360_Glance).

## Setup
1. `git switch -c {BRANCH} transition/main`. (For WP00 only: `transition/main` does not exist yet. Skip this step and follow the card, which creates `transition/main` from `dev/eb` and commits on it.)
2. Read, in order:
   - Your card: `.docs/transition/work-packages.qmd`, anchor `{CARD_ANCHOR}`
   - `.docs/transition/contract.qmd` and every file under `.docs/transition/contract/*.csv`
   - The standard: `.docs/data-standard.qmd`
   - `.docs/transition/decisions.qmd`

## Task
Do the work your card describes: produce exactly the paths it lists under "Owned outputs", by following its "Steps". Before you finish, self-check against every one of the card's "Acceptance checks" (`{WP_ID}.A<n>`) — you will never see the verifier's script, so re-derive each check yourself from the card and the contract and confirm it holds.

## Hard rules (yours to enforce; the orchestrator will not remind you)
- Touch only the paths your card lists under "Owned outputs". If a step needs a path you do not own, or the contract looks wrong or inconsistent with the standard, STOP and write up the problem in your report instead of working around it.
- Never edit the contract (`.docs/transition/contract.qmd`, `.docs/transition/contract/*.csv`), the cards, the decisions or the templates; they are frozen. Before committing, check that every path in `git diff --name-only transition/main...HEAD` is owned by {WP_ID} in `contract/output_ownership.csv` (your report under `.docs/transition/reports/` included). If one is not, remove that change or stop and report.
- Quarto on this machine: `QUARTO_R` is broken. Always run `env -u QUARTO_R quarto render <file>` (Git Bash), and delete render outputs that you do not own.
- Never edit anything under `data_raw/` — it is byte-frozen; its checksums are in `data_raw/CHECKSUMS.sha256`.
- Never push, and never switch to or touch `dev/eb`, `master`, or `transition/main` directly.
- Never mark any code or row `ACTIVE` — everything this transition produces stays `DRAFT` unless the card explicitly says otherwise.
- You are a Sonnet agent: do not launch other agents.
- Run your own tests before you finish.

## Finishing
1. Commit your work on `{BRANCH}` with message `{WP_ID}: <one-line summary>`, ending with the Co-Authored-By trailer your harness appends to commits.
2. Write your report at `.docs/transition/reports/{WP_ID}-implementer.md`, following every section of `.docs/transition/templates/implementer-report.md` — write "None" rather than omitting a section.
3. `git switch --detach` so the branch is not locked to this worktree.
4. Your final message to the orchestrator is plain text, at most 150 words: what you wrote, what passed, any deviations or open questions. Do not paste the full report — the orchestrator reads that from disk.
```
