# Wave 1 integration report (run 2)

This is a follow-up to the first wave-1 integration (commit `8d1cd6b`, report
`WAVE1-integration.md`), which reported `STATUS: FINDINGS` for one failure,
`WP01.A4`. This run merges only the corrected WP01 branch.

## Merged

| Package | Branch | Merge commit |
|---|---|---|
| WP01 | transition/wp01-data-raw-v2 | 48a09ae |

No other branch was in scope for this run.

## Conflicts

None. The merge (`git merge --no-ff transition/wp01-data-raw-v2`) completed with no conflicts;
only three files changed (`.docs/transition/reports/WP01-implementer-p1.md`,
`.docs/transition/reports/WP01-verifier-v2.md`, `pipeline/acceptance/wp01_data-raw.R`), none of
them CHANGELOG.md or STATUS.md.

## Checks

| Check | Result |
|---|---|
| `Rscript pipeline/acceptance/run_all.R --root .` | PASS — `wp01_data-raw.R` SUMMARY: PASS (exit 0), including WP01.A4; `wp02_standard-v04.R` PASS; `wp03_scaffold.R` PASS |
| `Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"` | PASS — `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 49 ]` |
| `Rscript .docs/transition/contract/check_contract.R --root .` | PASS — all 27 contract checks passed, "All contract checks passed." |
| `sha256sum -c data_raw/CHECKSUMS.sha256 \| grep -vc ': OK$'` | PASS — printed `0` |
| `env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render index.qmd` | PASS — "Output created: _site\index.html", all 30 cells executed, no error |

## Findings by owner

None. Every check in step 3 passed. The prior finding (`WP01.A4` FAIL, owner WP01/its acceptance
script) is resolved: the verifier on `transition/wp01-data-raw-v2` corrected
`pipeline/acceptance/wp01_data-raw.R` so its own committed source no longer contains the literal
`"INPUT "` token (it is now reassembled at runtime via a `legacy_word()`-style helper), removing
the self-referential false positive. `Rscript pipeline/acceptance/wp01_data-raw.R --root .` now
reports `CHECK WP01.A4 PASS tracked paths starting 'INPUT ' = 0; git grep exit=1 (1 expected = no
match; first match: none)`.

## Status changes

- WP01: MERGED (unchanged) — branch updated `transition/wp01-data-raw-v1` -> `transition/wp01-data-raw-v2`, verdict PASS, attempts 1 -> 2, date 2026-09-22.
- WP00, WP02, WP03: unchanged (already MERGED from the first wave-1 run; not part of this merge).
- No gate changes. Gate G0 was already recorded (`reports/GATE-G0.md`, first wave-1 run); not re-written or edited here.

## Changelog lines added

None. WP01's changelog line ("Legacy inputs moved to data_raw/ (byte-identical, 122 files).") is
unchanged from the card per both `WP01-implementer-p1.md` and `WP01-verifier-v2.md`, and is
already present in `metadata/CHANGELOG.md` under "## 0.1.0 (unreleased)" from the first
integration. This run's merge corrected only the acceptance script (owned by the verifier, not a
WP01 deliverable), so it was not duplicated. `metadata/VERSION` was not changed (stays `0.1.0`).
