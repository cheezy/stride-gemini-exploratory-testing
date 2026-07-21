# Example charters

A worked, risk-ranked charter set produced by `/charter` (via the `charter-generator` agent) for a **synthetic** target: the CSV **card import** on *Acme Board*, a fictional demo kanban app running at the reserved host `http://demo.example.com`. Every value here is invented — no real customer data, hostnames, or credentials.

Each charter follows the canonical template:

> **Explore** `<target>` **with** `<resources>` **to discover** `<information>`.

Charters are ordered **highest risk first**. Charter 1 is the one carried through the companion fixtures — [`example-session-sheet.md`](example-session-sheet.md) runs it, and [`example-debrief.md`](example-debrief.md) reports it — so a reader can follow one charter from mission to debrief.

---

## 1. CSV import — malformed & oversized files  ·  risk: high

**Explore** the CSV card import **with** malformed and oversized files (unclosed quotes, wrong delimiters, 50k-row / 12 MB files, duplicate re-uploads) **to discover** how the parser fails and whether it silently drops rows or corrupts existing board data.

- **Target:** the CSV card-import flow (upload → column mapping → commit)
- **Resources:** hand-crafted malformed CSVs, an oversized generated CSV, a second identical file for a duplicate-import test
- **Information:** does the parser fail *loudly* or *silently*? Can it drop rows, double-create cards, or damage existing cards?
- **Source:** nightmare-headline ("Import Silently Drops Half a Team's Tasks")
- **Lens:** Violate Format, Goldilocks (too big / too small), Interrupt, Follow the Data
- **Time-box:** ~90 min

## 2. Import idempotency & retries  ·  risk: high

**Explore** the CSV import **with** the same file uploaded twice and with the request interrupted mid-commit **to discover** whether the import is idempotent or creates duplicate / partial cards on retry.

- **Target:** the import commit step and its retry behavior
- **Resources:** one valid CSV, a network-throttling proxy to interrupt the commit
- **Information:** duplicate charges of the data model — does a retried or double-submitted import double the board?
- **Source:** implicit-expectation (retries should be safe)
- **Lens:** Interrupt, Back / Forward / Resubmit
- **Time-box:** ~60 min

## 3. Column-mapping UI  ·  risk: medium

**Explore** the import column-mapping screen **with** ambiguous headers, duplicate mappings, and missing required columns **to discover** inconsistent validation and how unmapped or double-mapped fields are handled.

- **Target:** the column-mapping step of the import wizard
- **Resources:** CSVs with duplicate headers, missing "title" column, extra unknown columns
- **Information:** can two CSV columns map to the same field? What happens to a row with no title?
- **Source:** sfdpot (Function)
- **Lens:** CRUD, Zero / One / Many
- **Time-box:** ~45 min

## 4. Import authorization & tenancy  ·  risk: medium

**Explore** the import endpoint **with** two demo tenants' boards present **to discover** whether an import can write cards into a board the current user does not own.

- **Target:** the import endpoint's board-ownership checks
- **Resources:** two demo accounts (`ann@demo.example.com`, `ben@demo.example.com`), a captured import request
- **Information:** cross-tenant write — can Ann's import land on Ben's board by tampering the board id?
- **Source:** nightmare-headline ("User Imports Tasks Straight Into a Stranger's Board")
- **Lens:** Tamper the URL, Follow the Data
- **Time-box:** ~60 min

## 5. Character encoding & internationalization  ·  risk: low

**Explore** the CSV import **with** non-UTF-8 encodings, emoji, RTL text, and very long unicode titles **to discover** mojibake, truncation, or layout breakage in imported card titles.

- **Target:** encoding handling in the import parser and card rendering
- **Resources:** CSVs saved as UTF-16 and Latin-1, a row with a 2,000-character emoji title
- **Information:** where does encoding get lost — parse, store, or render?
- **Source:** artifact (the importer docs claim "UTF-8 only" but the UI accepts any file)
- **Lens:** Special Characters & Injection, Goldilocks
- **Time-box:** ~45 min

---

> These charters give **direction, not steps**. Each poses an open *…to discover…* question — none is a check with a single known expected result. Un-run charters go on a backlog; new charters discovered mid-session (see the parking lot in the session sheet) are added to it.
