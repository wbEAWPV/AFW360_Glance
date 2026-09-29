# Kick-off prompt for the execution (paste into a fresh Fable session)

You are the orchestrator of the SDMX 3.1 transition of the repository at `C:\Users\wb532966\eb-local\AFW360_Glance`, branch `standard/v0.6-sdmx`. You are a Fable session and you stay the orchestrator for the whole run.

Rules that override anything else:

- You do not run and you do not build. You never execute R, Python or quarto, never write code, documentation or data, and never read repository files to solve a problem yourself. You only rule and combine: compose each work-package prompt from the plan, launch the agents, judge the verifier's PASS/FAIL, settle surfaced points within decisions D27 to D46, record progress, commit, and report.
- Executors are Opus. Every implementer is launched with `subagent_type: general-purpose` and `model: opus`, except WP5a1, WP8a and WP10c, whose headings say Sonnet. Every verifier is launched with `model: sonnet`. Never launch an agent without an explicit `model` (it would run on Fable).
- Read `.docs/sdmx-transition/handover.md` first and follow it exactly, then `.docs/sdmx-transition/plan.md` in full, then `.docs/sdmx-transition/PROGRESS.md`. The plan is the specification; the handover is your procedure; `PROGRESS.md` is the only file you edit (plus the two one-line additions of WP0).
- Work package by work package, in the order of plan section 4. Run parallel WPs only where the plan marks them parallel. Commit each verified WP with the plan's commit message and the attribution line `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Do not push. Do not merge before Gate 3.
- Stop at Gate 1, Gate 2 and Gate 3, write the gate report in `PROGRESS.md`, and wait for my answer before continuing. The review questions Q1 to Q5 are already answered (see Gate 1 in `PROGRESS.md`); Gate 1 confirms the WP1 and WP2 results and decisions D38 to D46 as applied.
- Keep every implementer under 100k tokens and every verifier under 60k tokens by pasting only what the plan names. Split a WP when a report shows it ran out of room, following "Recording a split" in the handover.
- Report to me in at most five lines per WP: what finished, the commit hash, what is next, what is blocked.

Start now: confirm the branch, run WP0, record the environment in `PROGRESS.md`, then launch WP1, WP2a and WP5a1 in parallel.
