# Template: implementer prompt

Use once per package, or once per stage for WP02. Agent parameters: `model: "sonnet"`, `isolation: "worktree"`, no `subagent_type`, and a `description` such as "Implement WP05". The prompt is the block below with every placeholder filled in.

| Placeholder | Value |
|---|---|
| `{WP_ID}`, `{WP_TITLE}` | From the package table in `plan.qmd` |
| `{BRANCH_COMMAND}` | `git switch -c transition/wpNN-<slug> transition/main`. For WP02 stage B it is `git switch transition/wp02-standard-v04`. For WP00 it is "Follow your card; it creates the branch." |
| `{REPORT_FILE}` | `WPNN-implementer.md`. For WP02 it is `WP02-implementer-A.md` or `WP02-implementer-B.md`. |
| `{NOTES}` | "None", or one line each for: the stage (`STAGE: A` or `STAGE: B`); gate answers the card asks for (`MESSAGES_SOURCE: dashboard`); the user's G1 notes for this package, word for word; and the card corrections reported by WP99 for this card. For WP99 itself, this holds the `DECISIONS` block. |

```
You are the IMPLEMENTER of work package {WP_ID} ({WP_TITLE}) in the AFW 360 data transition (repository AFW360_Glance).

1. Set up your branch: {BRANCH_COMMAND}
2. Read .docs/transition/packages/COMMON.md, then your card .docs/transition/packages/{WP_ID}.md.
   These two files are your whole brief. Read nothing beyond what the card's "Read" section lists;
   your session must stay under 100,000 tokens (COMMON.md section 1).
3. Do the card's steps and produce exactly its "Owned outputs". Before you finish, check your work
   against every acceptance check on the card yourself. You will never see the verifier's script.
4. Write your report to .docs/transition/reports/{REPORT_FILE}, commit everything in one commit,
   and run `git switch --detach` (COMMON.md sections 7 and 8).
5. End with the final message of COMMON.md section 8: a STATUS line, then at most 120 words.

Rules that override everything else:
- Touch only the paths your card owns. If the card, the contract and the inputs disagree, stop and report it.
- Never push. Never touch dev/eb, master or transition/main. Never mark anything ACTIVE.
- Do not launch other agents.

Notes from the orchestrator (these override the card where they differ):
{NOTES}
```
