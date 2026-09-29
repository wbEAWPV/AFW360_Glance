# Review and hardening of the SDMX 3.1 transition plan

You are the review lead for the plan in `.docs/sdmx-transition/` of the repository at `C:\Users\wb532966\eb-local\AFW360_Glance`, branch `standard/v0.6-sdmx`. The plan will be executed later by an orchestrator that writes no code and delegates each work package to an Opus or Sonnet implementer. Every implementer must finish under 100k tokens of context, so every work package must be small, self-contained and verifiable by a fresh Sonnet agent with no other knowledge.

Your job: find everything in the plan that is wrong, missing, inconsistent, too large, or not verifiable, fix it, and prove it is fixed. You do not implement the plan, you do not install software, and you do not touch repository files outside `.docs/sdmx-transition/`.

## The documents

| File | Lines | What it is |
|---|---|---|
| `plan.md` | 655 | Section 1 decisions D27 to D46; section 2 target design (2.1 to 2.14); section 3 work packages WP0 to WP11 and Gates 1 to 3; section 4 order; 5 risks; 6 conformance checklist; Appendix A research pointers |
| `handover.md` | 62 | Operating instructions for the orchestrator |
| `PROGRESS.md` | 72 | Status log the orchestrator maintains; its WP table must mirror the plan |
| `sdmx-ml-cheatsheet.md` | 255 | SDMX-ML 3.1 and SDMX-CSV 2.1 facts implementers get instead of the research |
| `research/R1_sdmx31_structures.md` | 972 | SDMX-ML 3.1 research (secondary source; may be wrong) |
| `research/R2_tooling.md` | 126 | Tooling research (pysdmx, FMR, R packages) |
| `research/R3_global_codelists.md` | 166 | Global registry findings |
| `research/R4_repo_inventory.md` | 811 | Repository inventory at planning time |

Primary sources outrank the research and the plan:

- SDMX-ML 3.1.0 schemas: `https://raw.githubusercontent.com/sdmx-twg/sdmx-ml/v3.1.0/schemas/<file>.xsd` (entry `SDMXMessage.xsd`).
- SDMX-CSV 2.1.0: `https://github.com/sdmx-twg/sdmx-csv` (data message and metadata message field guides under `data-message/docs/` and `metadata-message/docs/`).
- SDMX 3.1 information model and REST 2.2: `https://github.com/sdmx-twg/sdmx-im`, `https://github.com/sdmx-twg/sdmx-rest`.
- Global registry: `curl --ssl-no-revoke https://registry.sdmx.org/sdmx/v2/structure/...` (plain `curl` fails on this machine).
- The repository itself for every path, function, column and file the plan names.

Fixed constraints you must not change: decisions D27 to D46 in `plan.md` section 1. They are the data lead's. If a finding can only be resolved by changing a decision, do not change it; put it under "Questions for the data lead" in the review report and leave the plan text as is, with a `> REVIEW QUESTION Q<n>` note at the spot.

Environment facts: Windows 11, Git Bash for shell, Rscript 4.5.3, Python 3.11.9 in `.venv`, quarto 1.10.18, Java 21 present, Docker absent. Install nothing.

## Work-package size rules (what "small and manageable" means)

Apply these to every WP. A WP that breaks one must be split or trimmed.

1. Input budget: the implementer prompt (the WP section, the plan sections it says to paste, and the files and line ranges in its context list) must be at most 40k tokens. Estimate tokens as bytes divided by 4 (`wc -c` on files, `sed -n 'a,bp' | wc -c` on ranges).
2. Output budget: at most about 800 lines of new or changed code, data or documentation, and at most 8 files created or changed.
3. Verification: at most 10 checks, each an executable command with the expected output stated, or an objective file-state check (`grep -c`, `test -f`, a column count) that a fresh Sonnet agent can run knowing only the repository path and the check text.
4. Self-contained: when the WP section and its named plan sections are pasted, the implementer needs no other section of the plan, no research file, and no repository file outside its context list.
5. One concern per WP: a WP that mixes a generator, its tests and its documentation beyond a paragraph is split along file lists, never by widening context.
6. Dependencies: every file a WP reads must be produced by a WP it depends on or exist in the repository today.

Splitting rule: keep WP ids stable. Split `WP3` into `WP3a`, `WP3b`; never renumber. Every new WP gets the full structure (goal, model, context list, deliverables, constraints, verification list, commit message) and appears in section 4 and in the `PROGRESS.md` table.

## Step 1. Read, alone

Read `plan.md`, `handover.md`, `PROGRESS.md` and `sdmx-ml-cheatsheet.md` in full. Do not read the research files or the repository code yourself; reviewers will, and you must keep your own context for triage and editing. Create `review/` and an empty `review/FINDINGS.md`.

## Step 2. Launch seven reviewers in parallel

Use the Agent tool with `subagent_type: general-purpose` and the model named for each reviewer. Each reviewer prompt is self-contained: paste the common rules below, the reviewer's scope, its sources and its checks. Give each a short description with its id. Launch all seven in one message.

### Common rules (paste verbatim into every reviewer prompt)

```
Repository: C:\Users\wb532966\eb-local\AFW360_Glance, branch standard/v0.6-sdmx. Plan folder: .docs/sdmx-transition/.
Read only the files and line ranges assigned to you. Read with `sed -n 'a,bp'` or `grep -n`; never print more than 300 lines of a file at once. Data files: `head -3` only. Fetch specifications with WebFetch or `curl --ssl-no-revoke`; fetch one schema or page at a time and quote only the clause you need.
Do not modify any file except your own report at .docs/sdmx-transition/review/<ID>.md. Do not install anything.
Finish under 100k tokens of context. Work through your checks in the order given; if you run short, stop and write exactly where you stopped under "## Not checked".
Report format, one block per finding:
### <ID>-<n>
Severity: blocker | major | minor
  (blocker = an implementer following the plan would produce something non-conformant or could not complete;
   major = wrong or missing but recoverable; minor = clarity or consistency)
Where: <file> section <x.y>, line <n>
Claim: <one sentence>
Evidence: <spec clause with URL, or repository file:line, or the command you ran and its decisive output line>
Fix: <exact replacement text, or a precise instruction>
Mark anything you could not verify against a primary source as "Uncertain:" at the start of the Claim; never present an inference as a fact.
End with "## Verified OK" (what you checked and found correct, so the lead knows your coverage) and "## Not checked".
Your final message to the lead is at most 15 lines: counts by severity, the blockers in one line each, and the path of your report.
```

### R-A, SDMX-ML 3.1 structural conformance (model: opus)

Scope: `plan.md` sections 2.1, 2.4, 2.5, 2.6, 2.8, 2.9 (lines 56 to 64 and 130 to 229) and the whole of `sdmx-ml-cheatsheet.md`. Secondary source: `research/R1_sdmx31_structures.md`, only the sections the cheatsheet cites.

Sources: the 3.1.0 XSDs, one at a time: `SDMXCommon.xsd`, `SDMXStructureBase.xsd`, `SDMXStructureCodelist.xsd`, `SDMXStructureConcept.xsd`, `SDMXStructureDataStructure.xsd`, `SDMXStructureDataflow.xsd`, `SDMXStructureMetadataStructure.xsd`, `SDMXStructureMetadataflow.xsd`, `SDMXStructureProvisionAgreement.xsd`, `SDMXStructureOrganisation.xsd`, `SDMXMessage.xsd`.

Checks: every element name, child order, attribute name and cardinality the plan or cheatsheet states; id and version rules (NCName versus IDType, semver, fixed-version schemes without a version attribute, dotted agency ids, sub-agency semantics); the DSD component table in 2.4 (dimension order, TimeDimension representation, measure `usage`, attribute relationships and measure relationships, `usage` on attributes); the semver rule that forbids a semver artefact referencing a legacy-versioned one; MSD nesting of metadata attributes; Metadataflow target syntax including wildcards; ProvisionAgreement and MetadataProvisionAgreement; the annotation structure used for `AFW_*`, `GLOBAL_CODE` and `AFW_SENTINEL`. Resolve the plan's open item on Metadataflow wildcard targets with a spec citation.

### R-B, SDMX-CSV 2.1 data and metadata messages (model: opus)

Scope: `plan.md` sections 2.3, 2.7, 2.12 (lines 103 to 129, 195 to 211, 248 to 256), decisions D38, D39, D46 in section 1, and the SDMX-CSV parts of `sdmx-ml-cheatsheet.md`.

Sources: the SDMX-CSV 2.1.0 field guides for the data message and the metadata message on GitHub.

Checks: the fixed columns and their exact spellings; the `STRUCTURE` value and the `STRUCTURE_ID` format `AGENCY:ID(version)`; `ACTION` semantics and the choice of `R`; `NaN` and `#N/A` versus empty; the sub-field separator; the 37-column header and the sample row (count the fields in both; they must be 37); whether attribute columns attached above observation level may vary within a series; the metadata message header (`MDSTRUCTURE`, `MDSTRUCTURE_ID`, `METADATASET_ID`, `TARGET_TYPES`, `TARGET_IDS`), nested attribute headers, target syntax, and whether item-level targets (a code, a dataflow) are expressible. Resolve the plan's open item on the item-target short form with a citation, or state the fallback the plan should adopt.

### R-C, global alignment and registry facts (model: opus)

Scope: `plan.md` sections 2.5 and 2.9 (lines 167 to 190 and 216 to 229), decision D32, the codelist rows of 2.10, and all of `research/R3_global_codelists.md`.

Sources: the global registry via `curl --ssl-no-revoke`, one artefact per call, with `detail=allstubs` or `references=none` where possible to keep responses small.

Checks: each global codelist the plan names (agency, id, version) exists at that version; each global code value the plan relies on exists in that list (sentinels `_T` and `_Z` where claimed, `OBS_STATUS` codes `A`, `O`, `M`, `FREQ` code `A`, `UNIT_MEASURE` codes including `XOF`, the `CL_AGE` band ids, `CL_URBANISATION` and `CL_DEG_URB` codes); the URN format written in the `global_urn` column; whether agency `WB` exists and whether `WB.AFW360` is a legal sub-agency id without registration; whether the `CROSS_DOMAIN_CONCEPTS` concepts the plan reuses exist with the ids stated. Resolve the plan's open item on CL_AGE band ids.

### R-D, repository fit (model: opus)

Scope: `plan.md` sections 2.2, 2.10, 2.11, 2.14 (lines 65 to 102, 230 to 247, 271 to 274) and the context lists of WP1, WP2, WP3, WP4a, WP4b, WP9a, WP9b, WP9c.

Sources: the repository. Use `git ls-files`, `ls -R` of `pipeline/`, `metadata/`, `data/`, `.docs/`, and `grep -n` on `index.qmd`, `pipeline/*.R`, `pipeline/R/*.R`. Use `research/R4_repo_inventory.md` only as an index; verify against the files.

Checks: every path, function name, column name and file the plan cites exists today or is explicitly marked as new; the migration in 2.10 covers every file under `metadata/` (list them and tick them off); the "hard-coded layout" list in 2.11 is complete (run `grep -rn "data_raw\|DATAFLOW\|metadata/structure\|manifest" pipeline index.qmd` and compare); the loader plan in 2.14 matches how `index.qmd` reads data today; every line range quoted in a WP context list still points at the content the WP describes; the test layout under `pipeline/tests/` and the way tests are run match what the verification checks assume.

### R-E, work-package executability, WP0 to Gate 1 (model: opus)

Scope: `plan.md` lines 275 to 357 (section 3 preamble, WP0, WP1, WP2, Gate 1) and the plan sections each of those WPs tells the orchestrator to paste.

Sources: the plan itself, `handover.md`, and `wc -c` on the files each context list names.

Checks, per WP, against the six size rules: input tokens (show the arithmetic), output size, number and quality of verification checks (each must be a command or objective file-state check with its expected result), self-containment, dependencies, commit message present. For each WP that breaks a rule, propose the split with file lists. Also check that the section 3 preamble's baseline checks are runnable as written.

### R-F, work-package executability, WP3 to Gate 3, order, handover (model: opus)

Scope: `plan.md` lines 358 to 655 (WP3 to WP11, Gates 2 and 3, sections 4, 5, 6, Appendix A), `handover.md`, `PROGRESS.md`.

Sources: the plan itself and `wc -c` on the files each context list names. Read the pasted 2.x sections only where a WP names them.

Checks: the same per-WP checks as R-E for every WP in scope; the order string in section 4 matches each WP's stated dependencies and the `PROGRESS.md` table (same ids, same dependencies, same sequence); parallel pairs have disjoint file lists; each conformance-checklist row in section 6 maps to a verification check in a named WP (say which); each risk in section 5 names the WP or gate that handles it; the rules in `handover.md` (models, verification protocol, retry protocol, commit rules, context budget) are consistent with what the WPs assume, and it tells the orchestrator how to record a WP split.

### R-G, consistency sweep (model: sonnet)

Scope: all of `plan.md` and `sdmx-ml-cheatsheet.md`, read in 150-line slices, plus `handover.md` and `PROGRESS.md`.

Checks: every number is the same everywhere it appears (37 columns, 19 key columns, component counts, nine measures, six attributes, dimension count); the header line in 2.3, the DSD table in 2.4, decision D46 and the sample row agree column by column; every artefact id and version (`WB.AFW360`, `AFW360_HH`, `DSD_AFW360_HH`, `CS_AFW360`, `MSD_AFW360`, `0.3.0`, codelist ids) is spelled identically everywhere; every file path is spelled identically everywhere and appears in the layout of 2.2; every `D<nn>` referenced exists in section 1 and says what the reference claims; every "see section x.y" points at the right section; every WP id referenced exists; the cheatsheet and the plan do not contradict each other; `PROGRESS.md` lists exactly the WPs and gates in the plan.

## Step 3. Triage

When all seven reports are in, read each `review/<ID>.md`. Build `review/FINDINGS.md` as a table: finding id, severity, section, one-line claim, decision (`accept`, `reject` with reason, `question` for the data lead), resolution (what you changed, or the Q number).

Where two reviewers disagree, or a finding contradicts the plan on a point of the standard, settle it yourself against the primary source: fetch the exact XSD or field-guide clause and cite it in the resolution. Do not settle by majority or by trusting the research. A reviewer's "Uncertain" claim is a question for you to verify, not a finding to accept.

If a reviewer stopped early (its "Not checked" list is not empty), launch a fresh reviewer of the same type for only the unchecked part.

## Step 4. Fix the documents

Edit `plan.md`, `sdmx-ml-cheatsheet.md`, `handover.md` and `PROGRESS.md` in place. Rules:

- Keep decisions D27 to D46 unchanged. Questions go to the review report, with a `> REVIEW QUESTION Q<n>` note at the spot in the plan.
- Keep WP ids stable; split with suffixes; update section 4, the dependency lines of downstream WPs and the `PROGRESS.md` table together.
- After any edit that moves lines, re-check every line-range citation inside WP context lists (they cite plan sections and repository files by line) and fix them.
- Put a `Revised: 2026-..-.. (review round 1)` line under the plan title and a one-line entry in the `PROGRESS.md` log.
- Do not add prose about the review to the plan itself. The plan must read as instructions, not history.

## Step 5. Verify the revised plan yourself

Re-read the whole revised `plan.md` from the top. Then run this checklist and fix what fails:

1. Every WP has a goal, a model, a context list with line ranges, deliverables with paths, constraints, a verification list and a commit message.
2. Every WP satisfies the six size rules; show the input-token arithmetic for the three largest in `review/FINDINGS.md`.
3. The dependency graph has no cycle, section 4 states it exactly, and the `PROGRESS.md` table mirrors it.
4. Every path in a WP appears in section 2.2, and every path in 2.2 is produced by some WP or exists today.
5. The 2.3 header, the 2.4 table, D46 and the sample row agree column by column, 37 fields each.
6. Every verification check names its expected result.
7. `handover.md` still matches the plan (models, splits, gates, commit rules).
8. No `REVIEW QUESTION` note lacks a matching Q entry in the report, and no Q entry lacks its note.

## Step 6. Independent re-verification

Do not trust your own edits. Launch fresh Sonnet verifiers, at most three, each with a disjoint third of the `accept` rows of `review/FINDINGS.md`, the repository path, and this instruction: "For each row, open the cited location in the revised file and report PASS if the resolution text is present and correct as described, or FAIL with the quoted current text. Modify nothing." Launch one more Sonnet verifier with the R-G scope on the revised documents.

Fix every FAIL yourself and re-run a fresh verifier on the failed rows only. Repeat until every row passes. Record the verifier results in `review/FINDINGS.md` under a "Re-verification" heading, with the verifiers' PASS and FAIL lines.

## Step 7. Commit and report

Stage only `.docs/sdmx-transition/`. Commit on `standard/v0.6-sdmx` with:

```
SDMX transition plan: review round 1 (findings, fixes, re-verification)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

Do not push. Do not start any work package. Do not merge.

Final message to the data lead, at most 25 lines: findings by severity and by reviewer; the blockers and how each was fixed; WPs split and why; the open questions Q1 to Qn with your recommended answer for each; the commit hash; and whether the plan is ready for the orchestrator in `handover.md`, or what still blocks it.
