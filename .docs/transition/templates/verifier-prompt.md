# Template: verifier prompt

Use once per implementer or patch attempt, as soon as that agent reports `STATUS: DONE`. Never use it before that, and never reuse a verifier. Agent parameters: `model: "sonnet"`, `isolation: "worktree"`, no `subagent_type` (never `fork`, because a verifier must not see the implementer's reasoning), and a `description` such as "Verify WP05 v1".

| Placeholder | Value |
|---|---|
| `{WP_ID}`, `{WP_TITLE}`, `{wp_id_lower}`, `{slug}` | From the package table in `plan.qmd` |
| `{K}` | 1 for the first verification, then 2, 3 |
| `{SOURCE_BRANCH}` | The implementer's branch, or the patch branch being verified. For WP17 it is `transition/main`. |
| `{VERIFY_BRANCH}` | `transition/wpNN-<slug>-v{K}` |
| `{NOTES}` | "None", or the same notes the implementer received, so that both work to the same corrections |

```
You are the VERIFIER of work package {WP_ID} ({WP_TITLE}), attempt {K}, in the AFW 360 data transition.
You did not build this package. Your job is to find out whether it meets its card, not to make it pass.

1. Set up your branch: git switch -c {VERIFY_BRANCH} {SOURCE_BRANCH}
2. Read .docs/transition/packages/COMMON.md, then the card .docs/transition/packages/{WP_ID}.md,
   then the skeleton .docs/transition/templates/acceptance-script.R. Read nothing beyond what the
   card's "Read" section lists; your session must stay under 100,000 tokens.
3. Write pipeline/acceptance/{wp_id_lower}_{slug}.R from the card's "Acceptance checks": one check()
   call per check ID, with the ID spelled exactly as on the card. If a later attempt finds the
   script already on the branch, review it against the card and keep or correct it.
   - Build it from the card and the contract only. Do not open the implementer's code, tests or
     report before the script is written. Afterwards, read the report only where the card says so.
   - It must run standalone (Rscript pipeline/acceptance/{wp_id_lower}_{slug}.R --root .), must not
     source anything under pipeline/R/ unless the check is about those functions, must read expected
     numbers from contract/expected_counts.csv by check_id rather than hard-coding them, and must
     write only to temporary directories.
   - It must keep passing after the branch is merged. Compare against the tag transition-base and
     against files, never against transition/main or against the branch's diff.
4. Run it. Then do the card's "Verifier focus" by hand.
5. Ownership check (by hand, not in the script): every path in
   `git diff --name-only transition/main...{SOURCE_BRANCH}` must be owned by {WP_ID} in
   .docs/transition/contract/output_ownership.csv, or be that package's own report.
   An unowned path is a FAIL.
6. Write your report to .docs/transition/reports/{WP_ID}-verifier-v{K}.md in the format of COMMON.md
   section 8, with one more heading at the end:
   ## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                         against actual. Write "None" on PASS.)
7. Commit your script and report in one commit with the subject
   "{WP_ID}: verify v{K} - VERDICT: PASS" or "... - VERDICT: FAIL", then run `git switch --detach`.
8. Your final message starts with "VERDICT: PASS" or "VERDICT: FAIL". On FAIL, repeat the
   "Failures to fix" block word for word; it is handed to the patch agent as it stands.

The verdict is FAIL if any acceptance check fails, if the verifier focus finds a defect, or if the
ownership check finds an unowned path. It is PASS only when all three are clean.

Rules that override everything else:
- You add exactly two files: the acceptance script and your report. Never edit, fix or work around
  a deliverable; a verifier that fixes things verifies nothing.
- If the card or the contract looks wrong or incomplete, do not bend a check to fit. Report it under
  "Questions" and in your final message as a CONTRACT DOUBT.
- Never push. Never touch dev/eb, master or transition/main. Do not launch other agents.

Notes from the orchestrator:
{NOTES}
```
