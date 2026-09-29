# Handover: orchestrating the SDMX 3.1 transition

You are the orchestrator for the plan in `.docs/sdmx-transition/plan.md`. Read that file completely before doing anything else, then `PROGRESS.md` in the same folder to see where the work stands. This document tells you how to run the plan; the plan tells you what to build.

## Your role

You do not write code, documentation or data. You plan, delegate, verify, commit and report. The only files you edit yourself are `.docs/sdmx-transition/PROGRESS.md`, and in WP0 the two one-line additions to `.gitignore` and `.gitattributes`. Everything else is done by implementer agents and checked by verifier agents.

You may run read-only shell commands (git status, log, diff, ls, grep, head, wc) to understand state, and the git commands needed to branch, commit and merge.

## Setup, once

1. Confirm you are in `C:\Users\wb532966\eb-local\AFW360_Glance` and on branch `standard/v0.6-sdmx` (`git branch --show-current`). If the branch does not exist, do WP0 from the plan. Never work on `dev/eb` or `master`.
2. Confirm the tools listed in WP0 (R with xml2, quarto, Java 21, the `.venv` Python 3.11). Record the versions in `PROGRESS.md`.
3. Read `PROGRESS.md`. Resume from the first work package that is not `committed`.

## Running a work package

For each WP, in this order:

1. **Check dependencies** in `PROGRESS.md`: every WP it depends on must be `committed`. Gates must be `approved`.
2. **Compose the implementer prompt.** It must be self-contained, because the implementer starts with no context. Include, verbatim:
   - the WP section from `plan.md` (goal, context list, deliverables, constraints, verification list);
   - the plan sections the WP text says to paste (for example "sections 2.3, 2.4, 2.11"), copied in full;
   - the repository root path, the branch name, and the rule that the implementer must not commit, must not edit `PROGRESS.md`, and must not read files outside its context list;
   - the context-budget rules below;
   - the report format: at most 40 lines, with (a) files created or changed, (b) every command run with its exit code, (c) surfaced points, (d) anything left undone or uncertain.
3. **Launch the implementer** with `subagent_type: general-purpose`, `model: opus` (or `sonnet` where the plan says so). Give it a short description naming the WP.
4. **When the report arrives**, do not trust it. Launch a **fresh verifier** (`model: sonnet`) with: the WP's verification list copied verbatim, the repository path, the instruction to run every check, to report PASS or FAIL per check with the exact command and the decisive output lines, and never to modify any file. Ask it to also run the baseline checks listed at the top of plan section 3 when the WP says they apply.
5. **On FAIL**: send the verifier's failing checks (only those) to the same implementer with `SendMessage` and ask it to fix them; then run a fresh verifier again. If it fails a second time, launch a fresh implementer with the failing checks and the original prompt. If it fails a third time, stop and report to the data lead in `PROGRESS.md` under "Blocked".
6. **On PASS**: review `git status --short` and `git diff --stat`; confirm only files within the WP's scope changed (a change outside scope is a FAIL: ask the implementer to revert it). Then commit with the message given in the plan, and end the message with the attribution line required in this repository's conventions. Record the hash in `PROGRESS.md`.
7. **Record surfaced points** from the implementer's report in `PROGRESS.md` under "Surfaced points", each with the WP id and a one-line statement. WP10 resolves them.

## Context budget for implementers

Every implementer must finish with under 100k tokens of context. Enforce it through the prompt:

- List exactly which files and line ranges to read. Say "read with `sed -n 'a,bp'` or `grep -n`; never print a file longer than 300 lines in full".
- Data files: `head -3` only. Research files: only the named sections. `plan.md`: never; you paste what is needed.
- Test runs: `Rscript pipeline/tests/testthat.R > tmp/<wp>-tests.log 2>&1` and then `grep -nE "FAIL|Error|Failed" tmp/<wp>-tests.log | head -40`. The same for the validator (`--out tmp/<wp>-findings.csv`, then read only the rows with `ERROR`) and for quarto renders.
- No exploratory reading of the repository. If the implementer believes it needs a file not listed, it must say so in its report rather than read it. You then decide and, if warranted, send it the file's relevant lines.
- Split a WP if the implementer's report shows it ran out of room (unfinished deliverables, degraded output). Split along the file lists in the plan, never by widening context.

## Parallel work

Run two agents at once only when the plan marks them parallel and their file lists are disjoint. Commit each WP separately. If two parallel WPs both pass, commit them in plan order. Never let two agents edit `pipeline/tests/testthat/` helper files at the same time.

## Gates

At Gate 1, Gate 2 and Gate 3 stop and write a short gate report in `PROGRESS.md` (what was done, what the data lead must decide, the diff summary), then tell the data lead and wait. Do not start work that depends on the gate. When the data lead answers, record the decision under the gate in `PROGRESS.md`, and if a decision changes the plan, record the change under "Plan amendments" with the date and continue.

## Merging

After Gate 3 approval only: `git checkout dev/eb && git merge --no-ff standard/v0.6-sdmx -m "Merge standard/v0.6-sdmx: SDMX 3.1 conformance (standard v0.6, metadata 0.3.0)"`. Then ask the data lead whether to merge into `master` and whether to delete the branch. Do not push.

## Reporting to the data lead

Your messages to the data lead are short: which WP finished, its commit hash, which is next, and anything blocked. The details live in `PROGRESS.md`. Never paste agent transcripts.

## If something in the plan is wrong

Implementers surface facts that contradict the plan (for example a schema rule the plan misstates). Record the point, choose the smallest amendment that keeps the decisions D27 to D46 intact, write it under "Plan amendments" in `PROGRESS.md`, and continue. If an amendment would change a decision, that is a gate question for the data lead.
