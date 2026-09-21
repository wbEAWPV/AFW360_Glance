# Template: patch-agent prompt

Use it in three situations:

- after a verifier reports `VERDICT: FAIL`;
- after an implementer reports `STATUS: PARTIAL`, to continue its work;
- after an integrator reports validator or reconciliation findings against a package.

Agent parameters: `model: "sonnet"`, `isolation: "worktree"`, no `subagent_type`, and a `description` such as "Patch WP05 p1".

| Placeholder | Value |
|---|---|
| `{WP_ID}`, `{wp_id_lower}`, `{slug}` | From the package table in `plan.qmd` |
| `{K}` | The patch attempt for this package: 1, then 2 |
| `{SOURCE_BRANCH}` | After a FAIL: the verifier branch that failed, which already holds the acceptance script. After a PARTIAL: the implementer's branch. For integration findings: `transition/main`. |
| `{PATCH_BRANCH}` | `transition/wpNN-<slug>-p{K}` |
| `{MODE}` | `FAILURES`, `CONTINUE` or `FINDINGS` |
| `{INPUT}` | `FAILURES`: the verifier's "Failures to fix" block, word for word. `CONTINUE`: the implementer's final message. `FINDINGS`: the integrator's lines for this package: check_id, count and example rows. |

After the patch agent reports `STATUS: DONE`, launch a **fresh verifier** with `{SOURCE_BRANCH} = {PATCH_BRANCH}`. The verifier's own `{K}` counts verifier runs for the package: 1 if none has run yet (the usual case after `CONTINUE`), otherwise the last verifier's `{K}` plus one. A package gets at most 2 patch attempts. If it would need a third, ask the user.

```
You are the PATCH AGENT of work package {WP_ID}, attempt {K}, in the AFW 360 data transition. Mode: {MODE}.

1. Set up your branch: git switch -c {PATCH_BRANCH} {SOURCE_BRANCH}
2. Read .docs/transition/packages/COMMON.md, then the card .docs/transition/packages/{WP_ID}.md.
   Read nothing beyond what the card's "Read" section lists, plus the files named in the input below.
3. Your input:

{INPUT}

4. What to do, by mode:
   - FAILURES: fix the owned outputs of {WP_ID} so that every listed failure is resolved. Rerun
     pipeline/acceptance/{wp_id_lower}_{slug}.R and your tests until they pass.
   - CONTINUE: finish the card's remaining steps, exactly as an implementer would.
   - FINDINGS: first decide, from the card's rules, whether the code of {WP_ID} or another package's
     file is wrong. Look at the example rows, the check's code and the rule on the card. If {WP_ID}
     is wrong, fix it and add a unit test that reproduces the finding. If another package's file is
     wrong, change nothing: report the file, the row and the rule it breaks, so that the orchestrator
     can send a patch agent to its owner.
5. Write your report to .docs/transition/reports/{WP_ID}-implementer-p{K}.md (COMMON.md section 8).
   Under "Deviations", map each input item to exactly what you changed. Commit everything in one
   commit with the subject "{WP_ID}: patch p{K} - <summary>", then run `git switch --detach`.
6. Final message: a STATUS line (DONE, PARTIAL or BLOCKED), then at most 120 words.

Rules that override everything else:
- Touch only the paths {WP_ID} owns in .docs/transition/contract/output_ownership.csv.
- Do not edit an acceptance script. If you believe one is wrong, say exactly why in your report
  and final message, and stop there.
- Never push. Never touch dev/eb, master or transition/main. Do not launch other agents.
```
