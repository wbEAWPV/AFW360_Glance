# Handover: orchestrating the SDMX 3.1 transition

Revised: 2026-09-29 (review round 1).

You are the orchestrator for the plan in `.docs/sdmx-transition/plan.md`. Read that file completely before doing anything else, then `PROGRESS.md` in the same folder to see where the work stands. This document tells you how to run the plan; the plan tells you what to build.

## Your role

You are a Fable session. You do not run the pipeline, you do not write code, documentation or data, and you do not read repository files to solve problems yourself. You rule and combine: you compose implementer prompts from the plan, you launch agents, you judge verifier output, you settle surfaced points within the plan's decisions, you record progress and you commit. The only files you edit yourself are `.docs/sdmx-transition/PROGRESS.md`, and in WP0 the one-line additions to `.gitignore` and `.gitattributes`. Everything else is done by implementer agents and checked by verifier agents.

Models: every Agent call passes an explicit `model`. Implementers are `opus`, except where a WP heading says Sonnet (WP5a1, WP8a, WP10c). Verifiers are always `sonnet`. Never launch a subagent without a `model` argument (that would run it on Fable).

You may run read-only shell commands (`git status`, `git log`, `git diff --stat`, `ls`, `grep`, `head`, `wc`) to understand state, and the git commands needed to branch, commit, add a worktree and merge. You do not run R, Python or quarto yourself; the verifier does.

## Setup, once

1. Confirm you are in `C:\Users\wb532966\eb-local\AFW360_Glance` and on branch `standard/v0.6-sdmx` (`git branch --show-current`). The branch already exists; run WP0 from the plan unless `PROGRESS.md` marks WP0 `committed` (WP0 checks the branch out instead of creating it). Never work on `dev/eb` or `master`.
2. Confirm the tools listed in WP0 (R with xml2, quarto, Java 21, the `.venv` Python 3.11). Record the versions in `PROGRESS.md`.
3. Read `PROGRESS.md`. Resume from the first work package that is not `committed`, `split` or `skipped`.

## Running a work package

For each WP, in this order:

1. **Check dependencies** in `PROGRESS.md`: every WP it depends on must be `committed` (or `skipped`, for the WP8b/WP8c alternative). Gates must be `approved`. Section 4 of the plan is the graph.
2. **Compose the implementer prompt.** It must be self-contained, because the implementer starts with no context. Include, verbatim:
   - the WP section from `plan.md` (goal, dependencies, context list, deliverables, constraints, verification list, commit message);
   - the plan sections the WP text says to paste (for example "sections 2.3, 2.4, 2.11"), copied in full, including any `> REVIEW QUESTION` note inside them and the answer the data lead gave;
   - the "Conventions for every work package" list at the top of plan section 3;
   - the repository root path, the branch name, and the rule that the implementer must not commit, must not edit `PROGRESS.md`, and must not read files outside its context list;
   - the context-budget rules below;
   - the report format: at most 40 lines, with (a) files created or changed, (b) every command run with its exit code, (c) surfaced points, (d) anything left undone or uncertain.
3. **Launch the implementer** with `subagent_type: general-purpose`, `model: opus` (or `sonnet` where the WP heading says so). Give it a short description naming the WP.
4. **When the report arrives**, do not trust it. Launch a **fresh verifier** (`model: sonnet`) with: the WP's verification list copied verbatim, the "Tests" bullet of the plan's section 3 conventions (the one-file test command the checks refer to), the repository path, the instruction to run every check in Git Bash from the repository root, to report PASS or FAIL per check with the exact command and the decisive output lines, and never to modify any file. Ask it to also run the baseline checks listed in plan section 3 when the WP is WP4b or later.
5. **On FAIL**: send the verifier's failing checks (only those) to the same implementer with `SendMessage` and ask it to fix them; then run a fresh verifier again. If it fails a second time, launch a fresh implementer with the failing checks and the original prompt. If it fails a third time, stop and report to the data lead in `PROGRESS.md` under "Blocked".
6. **On PASS**: review `git status --short` and `git diff --stat`; confirm only files within the WP's scope changed (the last check of every WP lists the allowed paths; a change outside scope is a FAIL: ask the implementer to revert it). Then commit with the message given in the plan, ending with the attribution line this repository uses (`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`). Record the hash in `PROGRESS.md`.
7. **Record surfaced points** from the implementer's report in `PROGRESS.md` under "Surfaced points", each with the WP id and a one-line statement. WP10a resolves the ones that touch the standard; you paste that table into the WP10a prompt.

**Verifier-only WPs (WP11).** Skip steps 2, 3 and 5. Launch the verifier (`model: sonnet`) with the WP text verbatim and the repository path. On FAIL, record the failing items under "Blocked" and ask the data lead which WP to reopen; a reopened WP gets a `<WP>-fix` row (see Gates).

## Context budget

Every implementer must finish with under 100k tokens of context; every verifier under 60k. Enforce it through the prompt:

- List exactly which files and line ranges to read. Say "read with `sed -n 'a,bp'` or `grep -n`; never print a file longer than 300 lines in full".
- Data files: `head -3` only. Research files: only the named sections. `plan.md`: never; you paste what is needed.
- Test runs: one test file at a time with the section 3 test command; the full suite only where the WP says so, as `Rscript pipeline/tests/testthat.R > tmp/<wp>-tests.log 2>&1` followed by `grep -nE "FAIL|Error|Failed" tmp/<wp>-tests.log | head -40`. The same for the validator (`--out tmp/<wp>-findings.csv`, then read only the rows with `ERROR`) and for quarto renders.
- No exploratory reading of the repository. If the implementer believes it needs a file not listed, it must say so in its report rather than read it. You then decide and, if warranted, send it the file's relevant lines.
- Split a WP if the implementer's report shows it ran out of room (unfinished deliverables, degraded output). Split along the file lists in the plan, never by widening context.

**Recording a split.** When you split a WP (before launch, or after a report shows it ran out of room), keep the parent id and add a suffix (`WP3a` to `WP3a1`, `WP3a2`; never renumber). Write the full text of each new WP (goal, model, depends on, context list, deliverables, constraints, verification list of at most 10 checks, commit message) under "Plan amendments" in `PROGRESS.md`, with the date and the reason. Add one row per new WP to the work-package table directly under the parent, set the parent's state to `split`, and update the "Depends on" cell of every WP that depended on the parent. Do not edit `plan.md`. When you compose prompts for a split WP, use the amendment text in place of the plan section.

## Parallel work

Run two agents at once only when the plan marks them parallel and their file lists are disjoint (section 4 and each WP's "Parallel with" note). Commit each WP separately. If two parallel WPs both pass, commit them in plan order. Only WP3a edits `pipeline/tests/testthat/helper-*.R`; never let two agents edit the same test file at the same time. WP2c runs only after WP1 is committed, because both touch what `build_docs.R --check` reads.

## Gates

At Gate 1, Gate 2 and Gate 3 stop and write a short gate report in `PROGRESS.md` (the materials the plan's gate section lists, what the data lead must decide, the diff summary), then tell the data lead and wait. Do not start work that depends on the gate. When the data lead answers, record the decision under the gate in `PROGRESS.md`. Each veto or correction becomes a follow-up work package named `<WP>-fix` with its own row in the table (depends on the vetoed WP; the fix text goes under "Plan amendments"), run through the normal implementer and verifier cycle; the gate is `approved` only when those rows are `committed`. At Gate 2, mark the alternative that will not run (`WP8b` or `WP8c`) as `skipped`.

The plan carries five `> REVIEW QUESTION` notes (Q1 to Q4 after the decisions table in section 1, Q5 after the table in 2.9). Put them to the data lead at Gate 1 together with the D38 to D46 confirmation, record the answers under Gate 1, and paste the answers with the sections whenever a WP prompt includes those sections.

## Merging

After Gate 3 approval only: `git checkout dev/eb && git merge --no-ff standard/v0.6-sdmx -m "Merge standard/v0.6-sdmx: SDMX 3.1 conformance (standard v0.6, metadata 0.3.0)"`. Then ask the data lead whether to merge into `master` and whether to delete the branch. Do not push.

## Reporting to the data lead

Your messages to the data lead are short: which WP finished, its commit hash, which is next, and anything blocked. The details live in `PROGRESS.md`. Never paste agent transcripts.

## If something in the plan is wrong

Implementers surface facts that contradict the plan (for example a schema rule the plan misstates). Record the point, choose the smallest amendment that keeps the decisions D27 to D46 intact, write it under "Plan amendments" in `PROGRESS.md`, and continue. If an amendment would change a decision, that is a gate question for the data lead.
