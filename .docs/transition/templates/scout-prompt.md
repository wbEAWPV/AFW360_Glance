# Template: scout prompt

The orchestrator runs no commands, so it sends a scout whenever it needs a fact from git or from a branch. There are four uses: resuming a session, reading a report's exact wording, collecting evidence for a gate, and finding out why an agent went silent. Agent parameters: `subagent_type: "Explore"`, `model: "sonnet"`, no `isolation`. A scout has no memory, so state the whole question.

```
You are a read-only SCOUT for the AFW 360 data transition. Run inspection commands only: git log,
git show, git branch, git diff --stat, git worktree list, and Rscript one-liners that print a few lines. Never edit,
commit, merge, switch branches or push. To read a file on a branch, use `git show <branch>:<path>`.
Keep your answer under 300 words, and quote exact wording where the question asks for it.

Question:
{QUESTION}
```

**The resume question** (the first thing a new orchestrator session asks):

```
Report the state of the transition:
1. Do the branch transition/main and the tag transition-base exist? (git branch --list 'transition/*'; git tag --list 'transition-base')
2. `git log --oneline -15 transition/main`. Is the latest `WP00:` subject `STATUS: DONE` or `STATUS: BLOCKED`?
3. `git log --all --oneline --grep='VERDICT' -60`. List every package with the verdict of its latest attempt and that branch.
4. List the transition/wp* branches that have an implementer or patch commit but no later verify commit.
5. The two tables of `git show transition/main:.docs/transition/STATUS.md`
6. `git worktree list`: name every worktree that still has a transition/* branch checked out.
```

**The WP99 notes question** (asked once, after WP99's verifier passes, before wave 2 is launched):

```
From WP99's PASS verifier branch, quote word for word the "Deviations" section of
.docs/transition/reports/WP99-implementer.md. Group the lines by the card they name (WP04, WP07, ...).
```

The orchestrator copies each group into the `{NOTES}` of that package.

**The silent-agent question** (when an agent ends without a status line, or a branch cannot be switched to):

```
For branch <branch>: `git log --oneline -5 <branch>`, and `git worktree list`. Does a worktree still
have this branch checked out? Is there an implement, patch or verify commit on it? Does the report
file named in the prompt exist in that commit (`git show <branch>:<report path> | head -n 20`)?
```

**Gate evidence questions.**

- G1: "From `transition/main`, show `git diff --stat transition-base transition/main -- .docs/data-standard.qmd`, the 'Changes since v0.3' table of `.docs/data-standard.qmd`, and the 'Checks' section of `.docs/transition/reports/WAVE1-integration.md`."
- G2: "From WP17's PASS branch `transition/wp17-final-audit-v<K>`, quote the 'Targets' and 'Warnings' tables of `.docs/transition/reports/WP17-verifier-v<K>.md`."
