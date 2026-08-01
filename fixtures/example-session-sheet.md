# Example SBTM session sheet

A worked **Session-Based Test Management** sheet for **Charter 1** from [`example-charters.md`](example-charters.md), run by the `explorer` agent against the *synthetic* Acme Board demo app at `http://demo.example.com`. All data is invented — no real users, hostnames, or credentials. The companion [`example-debrief.md`](example-debrief.md) reports this same session.

This is the sheet in its **agent-run** form: the session is bounded by a probe budget rather than a clock, so it reports counts the agent actually kept instead of a wall-clock duration and Task Breakdown Metric percentages. (A human-run sheet uses `TESTER / DATE / DURATION` plus TBS percentages — see the `session` skill; a human with a clock can report those honestly, an agent cannot.) The JSON contract behind this shape is `session_sheet` in [`agents/explorer.md`](../agents/explorer.md).

Note tags used in the running log: `test-idea`, `question`, `risk`, `surprise`, `bug`, `off-charter`. Bugs and off-charter items also get their own sections below.

```
CHARTER
  Explore the CSV card import with malformed and oversized files to discover
  how the parser fails and whether it silently drops rows or corrupts existing
  board data.

TESTER / DATE
  explorer custom agent (stride-gemini-exploratory-testing) / 2026-05-14

SESSION BUDGET
  Probe budget: 12 (band 8-20)        Tool-call ceiling: 60
  Probes attempted: 8 (on-charter 6, off-charter 2)
  Probes that produced a finding: 6 (the wrong-delimiter and header-only
    files both behaved correctly and produced nothing worth recording)
  Tool calls used: 34
  Stopped: charter_quiet (4 of the 12 probes unspent - the budget is a
    ceiling, not a quota)

AREAS COVERED
  Import wizard: file upload, column mapping, commit step.
  Data: hand-crafted malformed CSVs (unclosed quote, wrong delimiter, empty
  file, header-only), a generated 12 MB / 50k-row file, and a duplicate
  re-upload of a valid 30-row file.
  Board state: a demo board pre-seeded with 30 existing cards, to check for
  corruption of existing data.
  Platform: Chrome 124 on macOS; single demo tenant (ann@demo.example.com).

HEURISTICS APPLIED
  Violate Format, Goldilocks, Follow the Data, Interrupt

NOTES
  [setup] Seeded board "Q2 Launch" with 30 cards from the sample CSV; verified
    baseline count = 30 before each destructive test.
  [test-idea] Violate Format: uploaded a CSV with an unclosed quote on row 14.
  [surprise] Import UI showed "Import complete — 13 cards added" and returned
    to the board. Expected 40 rows in the file; only 13 landed. No error,
    no warning. -> see BUG-1.
  [test-idea] Goldilocks (too big): uploaded the 12 MB / 50k-row file.
  [bug] Browser froze ~40s with no spinner or progress bar; looked hung. The
    import did eventually succeed. -> see BUG-2.
  [test-idea] Interrupt / Resubmit: uploaded the same valid 30-row file twice.
  [bug] Second upload created 30 more cards — board now has 90 (30 seed + 30 +
    30). No "already imported" guard. -> see BUG-3.
  [test-idea] Violate Format: uploaded a semicolon-delimited CSV where the
    importer expects commas -> rejected at the column-mapping step with
    "Could not detect columns". Clear, early, and non-destructive; no bug.
  [test-idea] Empty file and header-only file.
  [test-idea] header-only file -> "Import complete — 0 cards added" (reasonable).
  [surprise] Empty (0-byte) file -> generic 500 error page, not a friendly
    validation message. -> logged as a question, not confirmed a bug (may be
    an accepted edge for now).
  [question] Is there a documented maximum file size? The upload control
    accepts any size with no client-side limit.
  [risk] Existing cards were never modified or deleted in any run — no
    corruption of prior data observed. Good news for the headline risk.
  [off-charter] The export feature (unrelated to this charter) produces a
    download filename built from the raw board name — a board named
    "Q2/Launch" yields a filename with a slash. Parked, not chased here.
  [off-charter] Column-mapping screen let me map two CSV columns to the same
    "title" field without complaint. Parked as a candidate charter.

BUGS
  BUG-1 (major): Malformed CSV silently truncates the import.
    Repro: import a 40-row CSV whose row 14 has an unclosed double-quote.
    Observed: only rows 1-13 import; the UI reports "Import complete" with no
      error and no indication rows were dropped.
    Why wrong (oracle: Never silently lose user data): a parse failure that
      discards 27 of 40 rows while reporting success violates a Never rule —
      the user believes all their tasks imported.

  BUG-2 (minor): No progress feedback on large imports.
    Repro: import the 12 MB / 50k-row file.
    Observed: ~40s of frozen UI, no spinner or progress indicator; indistinguishable
      from a hang.
    Why wrong (oracle: consistency — Acme's other long operations show a
      spinner): a long op with no feedback reads as broken.

  BUG-3 (major): Import is not idempotent; duplicate upload doubles the board.
    Repro: import the same valid 30-row CSV twice.
    Observed: 30 duplicate cards created on the second import; no dedupe, no
      "this file was already imported" prompt.
    Why wrong (oracle: implicit expectation — a retried import should be safe):
      an interrupted-then-retried import would silently duplicate a whole board.

QUESTIONS / RISKS
  - Is there (or should there be) a maximum import file size and row count?
    The UI enforces none.
  - Empty (0-byte) file returns a raw 500 — is that an accepted edge or a bug
    to file? Needs a product decision.
  - Cross-tenant write (Charter 4) was NOT exercised in this session — the risk of
    importing into a board you don't own remains open.

OFF-CHARTER PARKING LOT
  - Export filename built from an unsanitized board name (slash / special chars)
    -> candidate charter: "Explore the report export with special-character
    board names to discover filename injection or path issues."
  - Column mapping allows two CSV columns -> same field
    -> candidate charter: "Explore the import column-mapping step with duplicate
    and conflicting mappings to discover silent data-overwrite."
```
