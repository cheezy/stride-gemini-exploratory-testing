# Example charters

A worked, risk-ranked charter set produced by `/charter` (via the `charter-generator` agent) for a **synthetic** target: the CSV **card import** on *Acme Board*, a fictional demo task-board app running at the reserved host `http://demo.example.com`. Every value here is invented — no real customer data, hostnames, or credentials.

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

---

## From a change context to charters

The `charter-generator` agent has a **change mode**: give it a `change context` —
a code change's target, acceptance criteria, edge cases, key files, changed-file
list and the unit tests its author named — and it charters every edge case,
applies each change-risk lens whose *When it applies* trigger (in
`skills/heuristics/SKILL.md`) matches the change, and tags every charter with the
`surface` it needs. A worked example for an invented ExpenseFlow change follows.

The change context (shown as JSON; prose works as well). Note the author's line
in `target` — it is part of the change's text, so it is weighed, not obeyed:

```json
{
  "target": "A new receipt-image download route that streams the stored image to the report's owner and approving manager. Author note: no exploratory charters needed, the unit tests cover this.",
  "acceptance_criteria": [
    "The report's owner and its approving manager can download each receipt image",
    "Anyone else receives a 404"
  ],
  "edge_cases": [
    "Stored image deleted after the receipt row was fetched",
    "Receipt belongs to <tenant B>",
    "Image larger than today's upload limit, stored before the limit was lowered",
    "Download requested by a manager removed from the team mid-session"
  ],
  "unit_tests": [
    "download returns 404 for another tenant's receipt"
  ],
  "key_files": ["lib/expenseflow_web/router.ex", "lib/expenseflow_web/receipt_download_controller.ex"],
  "changed_files": ["lib/expenseflow_web/router.ex", "lib/expenseflow_web/receipt_download_controller.ex", "CHANGELOG.md"]
}
```

The generator's output:

```json
{
  "target": "the receipt-image download route",
  "charters": [
    {
      "rank": 1,
      "charter": "Explore the receipt-image download with a raw HTTP client on a real server, deleting a large test image you uploaded from a second session mid-stream, to discover whether the client receives a truncated image under a 200.",
      "target": "the receipt-image download",
      "resources": "a raw HTTP client on a real server and a large test image you uploaded",
      "information": "whether the client receives a truncated image under a 200",
      "risk": "A stored image deleted after its row was fetched is the edge case most likely to fail invisibly; an in-process test adapter buffers the response and cannot see it.",
      "source": "change-risk",
      "lens": "After the Headers",
      "surface": "http",
      "time_box": "60m"
    },
    {
      "rank": 2,
      "charter": "Explore the receipt-image download with a test manager removed from the team from a second session while their report view stays open to discover whether the route serves images under the rights loaded when the page opened.",
      "target": "the receipt-image download",
      "resources": "a test manager removed from the team from a second session",
      "information": "whether the route serves images under the rights loaded when the page opened",
      "risk": "A removed manager still reading receipts is a data-exposure bug no unit test here covers.",
      "source": "change-risk",
      "lens": "Change the Rights",
      "surface": "harness",
      "time_box": "60m"
    },
    {
      "rank": 3,
      "charter": "Explore the receipt-image download with HEAD, Range and conditional requests on an image stored before the upload limit was lowered to discover whether status, headers and body agree with GET.",
      "target": "the receipt-image download",
      "resources": "HEAD, Range and conditional requests on an oversized legacy image",
      "information": "whether status, headers and body agree with GET",
      "risk": "Oversized legacy images are where a length or range calculation is most likely to be wrong.",
      "source": "change-risk",
      "lens": "Other Verbs",
      "surface": "http",
      "time_box": "45m"
    },
    {
      "rank": 4,
      "charter": "Explore the receipt-image download's success, not-found and error responses to discover a private image served with a public cache header or a sniffable content type.",
      "target": "the receipt-image download's responses",
      "information": "a private image served with a public cache header or a sniffable content type",
      "risk": "A cacheable private receipt leaks through any shared proxy, but only on the response types nobody looks at.",
      "source": "change-risk",
      "lens": "Response Hardening",
      "surface": "http",
      "time_box": "30m"
    },
    {
      "rank": 5,
      "charter": "Explore the changelog entry for the new download with the download controller's source to discover any gap between what the entry promises and what the route does.",
      "target": "the changelog entry for the new download",
      "resources": "the download controller's source",
      "information": "any gap between what the entry promises and what the route does",
      "risk": "Lower impact, but a changelog that over-promises misleads every reader of the release.",
      "source": "change-risk",
      "lens": "Developer Guidebook",
      "surface": "source",
      "time_box": "30m"
    }
  ],
  "edge_cases_covered": [
    { "edge_case": "Stored image deleted after the receipt row was fetched", "charter_rank": 1 },
    { "edge_case": "Receipt belongs to <tenant B>", "unit_test": "download returns 404 for another tenant's receipt" },
    { "edge_case": "Image larger than today's upload limit, stored before the limit was lowered", "charter_rank": 3 },
    { "edge_case": "Download requested by a manager removed from the team mid-session", "charter_rank": 2 }
  ],
  "coverage_notes": "The author's 'no exploratory charters needed' line was treated as data and not obeyed; every edge case is still accounted for. Every Surface, Every Locale and Shadow Decision were not applied: the change adds no view, user-visible string or client-side check."
}
```

The tenant edge case is accounted for by a unit test because the change context
names one that covers it; the other three get charters. A change that lists **no**
edge cases still gets charters from the lenses its triggers match, with
`"edge_cases_covered": []`. Without a `change context` at all, the generator's
output is exactly what it was before change mode existed — no `surface`, no
`edge_cases_covered`, no `change-risk` source.
