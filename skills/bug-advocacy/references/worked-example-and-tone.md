# bug-advocacy — worked example and tone

Reference for the `bug-advocacy` skill (`skills/bug-advocacy/SKILL.md`): the severity rubric applied to real bugs, and the dispassionate-tone rule in full. It is kept out of the skill so that loading the skill does not load these too; the ladder, the modifiers and the combination rule they apply stay in the skill.

## Worked example — rating the CSV import session

The three bugs from the extension's example session sheet and example debrief (`fixtures/`), rated against the ladder. (The Critical row is an added illustration — no bug in that session rated Critical.)

| Bug | Worst demonstrated failure | Ladder clause matched | Modifiers | Level |
|---|---|---|---|---|
| BUG-1 — malformed CSV silently truncates the import | A 40-row file imported 13 rows and reported "Import complete"; rows 15–40 were well-formed and were dropped without a signal | High — *a failed operation reporting success about work the product accepted as well-formed*, and *valid data lost with the affected records still identifiable* | Reach: generalized to any parse error, not just the unclosed quote — yes. Avoidability: the user cannot tell it happened, so cannot prevent or repair it — yes. Persistence: silent, and the incomplete board outlives the import — yes. **3 of 3, and it still stays High: rule 4 of the skill's combination rule says modifiers never produce a Critical, and no Critical ladder clause matches** | **High** |
| BUG-3 — import is not idempotent; a duplicate upload doubles the board | Re-importing the same valid 30-row file created 30 duplicate cards with no dedupe and no prompt | High — *valid data persisted wrong, affected records still identifiable* | Reach: reproduced for every file tried and on every repeat — yes. Avoidability: the user can see the duplicates and delete them — no. Persistence: wrong state persists but is plainly visible — no. **1 of 3, and one modifier never moves a rating (rule 2 of the skill's combination rule)** | **High** |
| BUG-2 — no progress feedback on large imports | ~40s of frozen UI on a 12 MB file, indistinguishable from a hang; the import then succeeded correctly | Moderate — *behavior wrong or misleading while the user works, where no wrong state survives* | none demonstrated | **Moderate** |
| *(illustrative)* Import accepts a CSV exported from another tenant's board | `<tenant B>`'s exported rows accepted into `<tenant A>` with no tenant check | Critical — *data crossing a boundary that must contain it* | irrelevant; Critical is the ceiling | **Critical** |

Three calibration notes, because these are the disagreements that actually happen:

- **Why the silent truncation is High and not Minor.** The malformed row itself is input the product could not have interpreted — that clause is Minor, and it is the one a quick read reaches for. But rows 15–40 were **well-formed** and were dropped anyway, and the UI reported success about the file it accepted. What the product accepted as well-formed is the line: had the only casualty been the one unclosed-quote row, this would be Minor.
- **Why the duplicate import is High and not Moderate.** Moderate requires that nothing incorrect survives. Thirty duplicate cards survive the action and sit in the user's board until someone removes them by hand. That the user can *see* them is why no modifier aggravates it — visibility is not correctness.
- **Why the frozen UI is Moderate and not High.** Nothing was lost, nothing was reported falsely, and the data after the import is right. The cost is confusion and a real chance the user kills the tab — a degraded workflow, which is the Moderate clause verbatim. Do not import the user's alarm into the rating.

## Say it clearly and dispassionately

Report the bug in neutral, precise language: what you did, what happened, why it is wrong. Nothing else. No blame, no sarcasm, no speculation about how anyone let this happen.

This is not politeness — it is **credibility, and credibility is the currency that gets your next bug fixed**. Inflated language costs it fastest. A reader who trips over "completely broken" and finds a broken filter learns to read your reports at a discount, and the discount is still applied when you file something that really is catastrophic.

**The severity field is where tone does the most damage**, because an inflated level is inflated language sitting in the one place a reader can check — and one Critical that a reader re-rates as Moderate teaches them to discount every Critical you file afterward, including the next real one. Spend no adjective that the demonstrated failure has not already earned: no all-caps, no exclamation marks, no "catastrophic" or "completely broken", and no level the ladder did not give you.

Deflation costs the same credibility from the other side — a Critical filed as Moderate to sound measured is not restraint, it is a boundary failure that someone will now schedule behind a typo.
