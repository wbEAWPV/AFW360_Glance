# GATE G0 report

Date: 2026-09-22 (asked while wave 1 ran). Asked through AskUserQuestion in four calls.

## Call 1

Q: "H1 - Non-food consumption share: how should it be coded?"
Options: Recommended = "Not stored; derived as 1 minus the food share." / Alternative = "Stored under an aggregate qualifier COICOP_CP02T13."
ANSWER: "Recommended"
Action: H1 CONFIRMED with the recommended coding (`DERIVED`, not stored as its own series). No change to the contract.

Q: "H2 - Own-production and market food shares: how should they be coded?"
Options: Recommended = "A new ACQ qualifier on CONS_SH with COICOP_CP01." / Alternative = "Two separate indicators."
ANSWER: "Recommended"
Action: H2 CONFIRMED with the recommended coding (new qualifier variable `ACQ` on `CONS_SH` + `COICOP_CP01`). No change to the contract.

Q: "H3 - Wage and non-wage employment: how should they be coded?"
Options: Recommended = "POP_SH with a new EMP_TYPE breakdown; the two sum to 1.00 exactly." / Alternative = "One JOB_WAGE indicator, with non-wage derived."
ANSWER: "Recommended"
Action: H3 CONFIRMED with the recommended coding (`POP_SH` with new breakdown `EMP_TYPE`). No change to the contract.

Q: "H4 - 'Employed': confirm the recommended coding?"
Options: Recommended = "Only EMP_STATUS_EMPLOYED is stored; 'not employed' is never derived." / Another answer = "The card lists no alternative for H4. Pick this to give a different coding in your own words."
ANSWER: "Recommended"
Action: H4 CONFIRMED with the recommended coding (map to `POP_SH` with breakdown `EMP_STATUS_EMPLOYED` only). No change to the contract.

## Call 2

Q: "H5 - 'HH workers' in trade and transport: how should it be coded?"
Options: Recommended = "POP_SH with a new EMP_ISIC breakdown (sections G and H), universe TBD." / Alternative = "Children of EMP_SECTOR_SER, or separate indicators."
ANSWER: "Recommended"
Action: H5 CONFIRMED with the recommended coding (`POP_SH` with new breakdown `EMP_ISIC`, universe `TBD`). No change to the contract.

Q: "H6 - 'HH workers' informally employed: which universe?"
Options: Recommended = "POP_SH with EMP_FORMAL_N, universe = employed persons." / Alternative = "Universe = wage employees only, as the dashboard labels it today."
ANSWER: "Recommended"
Action: H6 CONFIRMED with the recommended coding (`POP_SH` with new breakdown `EMP_FORMAL`, universe = employed persons). No change to the contract.

Q: "H7 - The three electricity indicators: keep or skip?"
Options: Recommended = "Three DRAFT codes, with a comment flagging the implausible Senegal grid-connection values." / Alternative = "Skip EN_GRID_CONN in both countries."
ANSWER: "Recommended"
Action: H7 CONFIRMED with the recommended coding (three `DRAFT` codes, `COMMENT` override on SEN `EN_GRID_CONN`). No change to the contract.

Q: "H8 - Average outage duration, the mean of an ordinal code: keep or skip?"
Options: Recommended = "Keep as DRAFT with unit INDEX." / Alternative = "Skip until the code scale is documented."
ANSWER: "Recommended"
Action: H8 CONFIRMED with the recommended coding (map as `DRAFT`, `unit_measure INDEX`). No change to the contract.

## Call 3

Q: "H9 - Cooker 'proxy' and clean cooking, implausible pattern in Senegal: keep or skip?"
Options: Recommended = "Keep as EN_ASSET_COOKER, with a comment on the clean-cooking rows." / Alternative = "Skip the cooker label."
ANSWER: "Recommended"
Action: H9 CONFIRMED with the recommended coding (`EN_ASSET_COOKER`, "proxy" dropped from the name, flagged for review). No change to the contract.

Q: "H10 - 'HH owns a non-agric enterprise' against 'has an enterprise owner': how should they be coded?"
Options: Recommended = "The first is derived from HE_COUNT, and the second is a new DRAFT indicator HE_HH_OWNER." / Alternative = "POP_HH_SH with an aggregate HE_COUNT_1P category."
ANSWER: "Recommended"
Action: H10 CONFIRMED with the recommended coding (#60 `DERIVED`; #59 mapped as new `DRAFT` indicator `HE_HH_OWNER`). No change to the contract.

Q: "H11 - Enterprise owner's sex and marital status: how should they be coded?"
Options: Recommended = "POP_HE_SH with new HEO_SEX and HEO_MSTAT breakdowns." / Alternative = "Two standalone indicators."
ANSWER: "Recommended"
Action: H11 CONFIRMED with the recommended coding (`POP_HE_SH` with new breakdowns `HEO_SEX`, `HEO_MSTAT`). No change to the contract.

Q: "H12 - 'HE has external employees', impossible values (96 to 100 %): keep or skip?"
Options: Recommended = "Keep as DRAFT with a comment." / Alternative = "Skip."
ANSWER: "Recommended"
Action: H12 CONFIRMED with the recommended coding (map `DRAFT`, universe `TBD`, `COMMENT` override). No change to the contract.

## Call 4

Q: "H13 - 'At least one member has health coverage': how should it be coded?"
Options: Recommended = "A household-level indicator SP_HEALTH_COV_HH." / Alternative = "POP_HH_SH with a breakdown."
ANSWER: "Recommended"
Action: H13 CONFIRMED with the recommended coding (new household-level indicator `SP_HEALTH_COV_HH`). No change to the contract.

Q: "H14 - Internet access, 0.00 or empty everywhere: skip or map?"
Options: Recommended = "Skip." / Alternative = "Map it with a comment."
ANSWER: "Recommended"
Action: H14 CONFIRMED with the recommended coding (`SKIP`). No change to the contract.

Q: "H17 - Household-head age cutoff, undocumented; the dashboard says '29+': which codes?"
Options: Recommended = "DRAFT codes that stay renamable until the producer confirms." / Alternative = "Keep LT35 and GE35 as the standard drafts them."
ANSWER: "Recommended"
Action: H17 CONFIRMED with the recommended coding (`DRAFT` codes, renamable, cutoff to be confirmed with the producer). No change to the contract.

Q: "T1 - Key messages. The dashboard's hard-coded messages and the Messages files differ in titles and bodies. Which is authoritative?"
Options: Dashboard (index.qmd) = "Recommended. WP10 takes the hard-coded messages as the source (MESSAGES_SOURCE: dashboard)." / Messages files = "WP10 takes Messages_<ISO3>.txt as the source (MESSAGES_SOURCE: files)."
ANSWER: "Dashboard (index.qmd)"
Action: T1 resolves to `MESSAGES_SOURCE: dashboard`; the orchestrator passes this to WP10 in wave 2. T1 is not a hard case in `decisions.qmd` (no section there to update).

## Summary

Every question was answered "Recommended" except T1, which was answered "Dashboard (index.qmd)" (itself T1's recommended option). No case was flipped, so WP99 was not launched and the contract seeds are unchanged. H1–H14 and H17 are now CONFIRMED in `.docs/transition/decisions.qmd` with user note "Recommended". H15, H16, H18 and H19 were already DECIDED by prior user decisions (D3, D4, D5) and were not asked at this gate.
