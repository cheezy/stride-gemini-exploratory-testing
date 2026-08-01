# Example debrief

A worked debrief for **Charter 1** from [`example-charters.md`](example-charters.md) — the same session recorded in [`example-session-sheet.md`](example-session-sheet.md). It uses the session skill's two complementary templates: **Explored / Found / Unknown** (the concise, stakeholder-facing summary) and **PROOF** (the fuller session review). All data is *synthetic*; the target is the demo Acme Board app at `http://demo.example.com`.

Everything below is an **externally verifiable fact** — what was actually observed. Results that were not observed live under "What remains unknown", never under "What I found".

> **Charter:** Explore the CSV card import with malformed and oversized files to discover how the parser fails and whether it silently drops rows or corrupts existing board data.
>
> **Tester / date / budget:** `explorer` custom agent (stride-gemini-exploratory-testing) · 2026-05-14 · 12-probe budget, 8 probes attempted

---

## Explored / Found / Unknown

### What I explored
The CSV card-import wizard end to end (upload → column mapping → commit) against a demo board pre-seeded with 30 cards. Inputs covered: an unclosed-quote CSV, a wrong-delimiter CSV, empty and header-only files, a 12 MB / 50k-row file, and a duplicate re-upload of a valid 30-row file. Chrome 124 / macOS, single tenant. **Deliberately not covered:** cross-tenant / authorization behavior (Charter 4), non-UTF-8 encodings (Charter 5), and any mobile browser.

### What I found (most important first)
1. **Silent row loss on malformed input (High).** A 40-row CSV with one unclosed quote imported only 13 rows and reported "Import complete" with no error — the user would believe all 40 tasks landed. *(BUG-1)*
2. **Import is not idempotent (High).** Re-uploading the same valid file created 30 duplicate cards with no dedupe or "already imported" guard — a retried or double-submitted import silently doubles the board. *(BUG-3)*
3. **No progress feedback on large imports (Moderate).** The 12 MB file froze the UI ~40s with no spinner, indistinguishable from a hang. *(BUG-2)*
4. **Reassuring result:** across every run, the 30 pre-existing cards were never modified or deleted — no corruption of prior data was observed.

### What remains unknown (the honest edge of the map)
- Whether the import can write into a board the user does not own — **not exercised** this session.
- Whether a maximum file size / row count exists or should; the UI enforces none.
- Whether the raw 500 on a 0-byte upload is an accepted edge or a defect — needs a product decision.
- Behavior under non-UTF-8 encodings and very long unicode titles (Charter 5).

---

## PROOF

| Letter | Notes |
|---|---|
| **P — Past** | Ran Charter 1 as a single budgeted session (12-probe budget, 8 probes attempted, 34 tool calls). Seeded a demo board with 30 cards, then imported a battery of malformed, empty, oversized, and duplicate CSVs, checking the existing card count before and after each destructive run. 6 of the 8 probes served the charter and 2 were valuable off-charter detours; 6 of the 8 produced something worth recording. Stopped on `charter_quiet` with 4 probes unspent. |
| **R — Results** | Covered the full import wizard for one tenant on one browser. Found 3 bugs (2 High, 1 Moderate), 3 open questions, and 2 parking-lot items that became candidate charters. Confirmed the headline risk (corruption of existing data) did **not** reproduce. |
| **O — Obstacles** | No client-side file-size limit made generating a "too big" case a guessing game. The 0-byte 500 error page gave no diagnostic detail. No staging data-reset button, so each destructive run needed a manual re-seed. |
| **O — Outlook** | Next sessions: run Charter 2 (idempotency under interruption) and Charter 4 (cross-tenant import authorization) — both high-risk and untouched here. File the two parking-lot charters (export filename handling, duplicate column mapping). Recommend a product decision on max file size and on the empty-file 500. |
| **F — Feelings** | Uneasy about the import path. Two independent ways to silently lose or duplicate a user's data turned up within the first few probes with only mild provocation, which suggests the parser's error handling was never a design focus. My instinct is that the authorization charter (4) will surface something too — worth prioritizing. |

---

## Severity-ranked bug list

Each bug carries the four RIMGEA products — the isolated minimal repro, the worst consequence actually demonstrated, how far it generalizes, and who it harms. A field nobody could establish says so rather than guessing.

**BUG-1 — High — Malformed CSV silently truncates the import and reports success**

- **Minimal repro:** a 2-row CSV whose first row has an unclosed quote — row 2 is dropped and "Import complete" is still shown. The 40-row file is not needed.
- **Worst observed:** 27 well-formed rows silently discarded while the UI reported success. Not demonstrated: whether dropped rows can overwrite existing cards — the 30 seeded cards were never touched in any run.
- **Generalization:** reproduces with any parse error, not just an unclosed quote; every row after the first bad one is lost regardless of count.
- **Stakeholder impact:** a user importing a backlog from another tool believes all their tasks landed, discovers the loss only by counting by hand, and may no longer have the source file.

**BUG-3 — High — Import is not idempotent; a duplicate upload doubles the board**

- **Minimal repro:** import any 1-row CSV twice — two identical cards. Neither the 30-row file nor the seeded board is needed.
- **Worst observed:** a 30-card board became 90 across two re-imports, with no dedupe and no "already imported" prompt.
- **Generalization:** reproduces for every file tried and on every repeat, not just the second. *Not established:* whether two concurrent tabs behave the same — parked as a candidate charter.
- **Stakeholder impact:** a user whose import appears to hang (BUG-2) and retries doubles their board, then removes the duplicates by hand with no tooling to help.

**BUG-2 — Moderate — No progress feedback on large imports**

- **Minimal repro:** any import over ~5 MB; the freeze scales with size and needs no particular content.
- **Worst observed:** ~40s of unresponsive UI, after which the import completed correctly. Nothing wrong survived it.
- **Generalization:** *not established* — the other long operations that would show whether this is systemic (export, bulk move) are outside this charter, so they were parked rather than probed.
- **Stakeholder impact:** a user cannot tell the app from a hang, and the plausible reaction — killing the tab and retrying — lands them in BUG-3.

## Follow-up parking lot (candidate charters)

- Explore the report **export** with special-character board names to discover filename injection or path issues.
- Explore the import **column-mapping** step with duplicate and conflicting mappings to discover silent data-overwrite.
- Explore the import endpoint with **two tenants** present to discover cross-tenant writes (Charter 4 — still un-run).
