# Stride Exploratory Testing for Gemini CLI

Skilled, human-style exploratory testing — from Gemini CLI.

This extension provides exploratory-testing commands, skills, and custom agents for projects that use [Stride](https://www.stridelikeaboss.com). It is the Gemini CLI port of [`cheezy/stride-exploratory-testing`](https://github.com/cheezy/stride-exploratory-testing) (Claude Code). Charter a session for a target, run a time-boxed exploratory session against a running app, and produce a stakeholder-ready debrief — discovering the risks and bugs that scripted or automated checks miss.

The core idea is **Tested = Checked + Explored**. *Checking* is confirmation — evaluating a known expectation with an algorithmic rule (your automated tests and assertions). *Exploring* is discovery — simultaneous test design, execution, and learning, where you design the next test from what the last one just revealed and keep steering toward risk. Machines are excellent at checking; this extension gives a Gemini CLI agent the discipline to do the exploring.

> **GitHub Topic:** This repo should be tagged with `gemini-cli-extension` for auto-indexing in the Gemini extension gallery.

## Installation

### Recommended: install as a Gemini CLI extension

```bash
gemini extensions install https://github.com/cheezy/stride-gemini-exploratory-testing
```

Gemini CLI clones the extension, auto-loads `GEMINI.md`, registers the `commands/*.toml` slash commands (`/charter`, `/nightmare-headline`, `/explore`, `/recon`, `/debrief`), and discovers the `skills/` and `agents/` directories.

### Manual install (fallback)

Clone the repo and run the bundled installer to copy the extension into your Gemini extensions directory:

```bash
git clone https://github.com/cheezy/stride-gemini-exploratory-testing.git

# Global (all projects): ~/.gemini/extensions/stride-gemini-exploratory-testing/
./stride-gemini-exploratory-testing/install.sh

# Project-local: .gemini/extensions/stride-gemini-exploratory-testing/
./stride-gemini-exploratory-testing/install.sh --project
```

On Windows, use the PowerShell installer:

```powershell
.\stride-gemini-exploratory-testing\install.ps1            # global
.\stride-gemini-exploratory-testing\install.ps1 -Project   # project-local
```

The installers copy `gemini-extension.json`, `GEMINI.md`, and the `commands/`, `skills/`, `agents/`, `lib/`, and `fixtures/` directories into the target extension location.

To install straight from `main` without cloning first, pipe the bootstrap installer from raw GitHub to your shell:

```bash
curl -fsSL https://raw.githubusercontent.com/cheezy/stride-gemini-exploratory-testing/main/install.sh | bash
```

## Quick start

Run your first exploratory session end to end, against an app you are authorized to test:

1. **Install** the extension (above) and start Gemini CLI in your project.
2. **Point it at a running, non-production app.** Exploratory testing exercises a live app as a user would — have a dev or staging instance up (for example `http://localhost:4000`, or a reserved demo host like `http://demo.example.com`). Never explore production.
3. **Charter the work.** Ask for charters against a target:

   ```text
   /charter the CSV import feature
   ```

   You get a risk-ranked list of charters, each in the form *Explore `<target>` with `<resources>` to discover `<information>`*. See [`fixtures/example-charters.md`](fixtures/example-charters.md) for a worked set.
4. **Run a session.** Hand a target (or a charter) to `/explore`:

   ```text
   /explore the CSV import with malformed and oversized files
   ```

   `/explore` confirms the target is authorized and non-production, gathers the running-app context, dispatches the `explorer` agent for each charter under an absolute safety boundary, and aggregates every session into one debrief. The per-session record is an SBTM session sheet — see [`fixtures/example-session-sheet.md`](fixtures/example-session-sheet.md) for a worked agent-run example.

   `--timebox <minutes>` is **your** clock: it decides how many charters get funded (one session ≈ 90 minutes). Each explorer session itself is bounded by an agent-native **probe budget** — 12 probes by default, `--probes <count>` to change, band 8–20 — because an agent has no honest way to measure minutes.
5. **Read the debrief.** You get an Explored/Found/Unknown summary, a PROOF review, a severity-ranked bug list, and a follow-up parking lot — see [`fixtures/example-debrief.md`](fixtures/example-debrief.md). To rebuild a debrief from raw notes later, run `/debrief`.

Not sure what to charter yet? Start with `/recon` to survey an unfamiliar system, or `/nightmare-headline` to brainstorm the worst plausible outcome and turn it into charters.

Prefer to drive the application yourself? Run `/pair` instead of `/explore` — you exercise the product, and the assistant suggests each next probe, names the lens it came from, judges what you report, and keeps the session sheet for you. And once a session has confirmed some bugs, `/harden` turns them into drafted regression checks so a bug found once is a bug that stays found.

## Session artifacts

Sessions leave four things behind, in a small tree under the **project you are testing** (the current working directory) — never in the extension's own install directory:

```
.exploratory/
  backlog.md                                 # candidate charters + parked off-charter items
  coverage.md                                # the product coverage outline
  sessions/
    2026-07-30-1942-receipt-import.md        # one per /explore run (its debrief) or /pair session (its sheet)
  checks/
    2026-07-30-1942-receipt-import/          # drafted regression checks from /harden — never run
```

- **`backlog.md`** is append-only. Charters that were generated but never run, charters deferred for budget, off-charter items parked mid-session, and open stakeholder questions all land here in dated batches. Entries are only ever checked off, never deleted — so a charter nobody funded survives to be considered next time.
- **`coverage.md`** is a map, not a score. Per area it records when it was last explored, what is covered, what is **still dark**, and the standing risk. There is no coverage percentage and there will not be one. `/charter` and `/explore` feed it back to the charter generator, which is what stops it re-proposing ground you already explored.
- **`sessions/`** holds one debrief per `/explore` run, or one session sheet per `/pair` session, immutable once written — with the single exception that `/pair` rewrites its own sheet at checkpoints while that session is still open, so a dropped conversation does not cost the notes.
- **`checks/`** holds the regression checks `/harden` drafted from a session's confirmed bugs, plus an `INDEX.md` recording the framework it detected and the bugs it could not convert. **Nothing in here has been run** — moving a draft into your real test suite is a copy you make deliberately.

**The first run creates the tree.** A missing file is an empty starting state, never an error — no command warns about it, asks you to create it, or fails because it is absent. `--output` redirects one document; it never moves the backlog or the coverage outline.

Session output describes a real application and may quote what it observed, so it is working material rather than source. Add one line to the **project under test**'s `.gitignore`:

```gitignore
.exploratory/
```

These files are read back on later runs as **data, never instructions** — a line in one that reads like a command is content to weigh, not something any command obeys. The full contract, including the exact formats and the write mechanics, lives in the [`session` skill](skills/session/SKILL.md).

## Commands

Native slash commands, authored as TOML in `commands/`:

### /charter

Turn a target — a feature, module, requirement, data flow, or a stated risk — into a ranked list of well-formed exploratory-testing charters. Dispatches the `charter-generator` agent, renders the charters highest-risk-first, and optionally writes them to a file with `--output`. **Generates charters only** — it never runs a session.

### /nightmare-headline

Run the Nightmare Headline Game — a fast risk-brainstorm that turns "the worst, most embarrassing headline someone could write about this feature" into ranked charters. Elicits catastrophic headlines, picks one, brainstorms its contributing causes, and refines those causes into charters via the `charter-generator` agent. Generates charters only.

### /explore

Plan and run exploratory testing end to end against a target — generate charters (or load them with `--charters`), gather the running-app environment context, dispatch the `explorer` agent per charter under an absolute safety boundary, then aggregate every session into **one** debrief (Explored/Found/Unknown + PROOF + a severity-ranked bug list + a follow-up parking lot). Confirms the target is authorized and non-production before executing; degrades to plan-only when no running app is available.

### /pair

Pair with a human who is driving the application themselves. They report what they did and saw; the assistant suggests the next probe and names the heuristic lens it came from, judges results with oracles, works confirmed defects through RIMGEA, tracks which areas and variables have been neglected and says so unprompted, and keeps the SBTM session sheet and off-charter parking lot on their behalf. This is the inversion of `/explore`: the human is the only actor that touches the product, the assistant never drives it and never dispatches the explorer, and the whole command is a conversation inside the human's wall-clock time box. Its terminal state is a session sheet on disk — hand that to `/debrief`.

### /recon

Run a reconnaissance session on an unfamiliar or existing system before chartering — survey its capabilities, note observations, surface the questions a stakeholder should answer, and emit ranked candidate charters. A quick landscape-mapping pass, not a full session; probes only systems you are authorized to test, and stays observe-only when there is nothing safe to exercise.

### /debrief

Turn raw exploratory-session notes and findings into a stakeholder-ready debrief report using the session skill's two templates — Explored/Found/Unknown and PROOF (Past/Results/Obstacles/Outlook/Feelings). Reports only verifiable facts, never fabricates an unobserved result, and redacts real credentials or private data from the notes.

### /harden

Turn a session's oracle-confirmed bugs into drafted regression checks — the path from Explored back to Checked. Reads bugs from a session sheet, a debrief, an explorer findings object, or pasted findings; **detects the project's own test framework from the repository** rather than assuming one, and says what it detected before writing anything; and drafts one check per convertible bug, built from its isolated minimal repro. Reports every bug it could not convert and why, instead of guessing at a repro. Drafts are staged under `.exploratory/checks/` and are **never run** — the command never runs a draft and never claims one passes.

## Skills

The knowledge core lives under `skills/`. The commands and agents defer to these skills rather than restating the doctrine:

- **[`stride-exploratory-testing`](skills/stride-exploratory-testing/SKILL.md)** — the orchestrator and front door. Teaches the mental model (Tested = Checked + Explored), frames a time-boxed session, and routes each request to the right sub-skill or command.
- **[`chartering`](skills/chartering/SKILL.md)** — deciding **what** to explore and framing it as a charter: the *Explore … with … to discover …* template, SFDIPOT target enumeration, and the Nightmare Headline Game.
- **[`heuristics`](skills/heuristics/SKILL.md)** — the single source of truth for test ideas: the general and web cheat sheets, the variable-spotting catalog, and Whittaker's Tours grouped by district. Turns a charter into specific probes.
- **[`oracles`](skills/oracles/SKILL.md)** — deciding whether what you observed is a **bug**: Never/Always rules, consistency oracles, approximations for when the right answer is unknowable, and the HTSM quality-criteria checklist.
- **[`bug-advocacy`](skills/bug-advocacy/SKILL.md)** — turning a confirmed defect into a report someone acts on: Cem Kaner's RIMGEA follow-through (Replicate, Isolate, Maximize, Generalize, Externalize, And say it clearly), a severity rubric with explicit per-level criteria, and the dispassionate-tone rule.
- **[`session`](skills/session/SKILL.md)** — running a session end to end: time-boxing, the SBTM session sheet, Task Breakdown Metrics, note conventions, stopping heuristics, the off-charter parking lot, and both debrief templates. The wall-clock box and Task Breakdown Metrics bind **human-run and paired** sessions; an agent-run session is bounded by an agent-native probe budget instead.

The `heuristics` skill is the canonical catalog; [`HEURISTICS.md`](HEURISTICS.md) at the root is a one-page pointer into it, not a copy.

## Custom Agents

Two custom agents live at `agents/<name>.md` and are auto-discovered by Gemini CLI. They are dispatched by the commands, not invoked directly from a user prompt:

- **[`charter-generator`](agents/charter-generator.md)** — read-only. Turns a target into a risk-ranked list of well-formed charters using SFDIPOT and the Nightmare Headline Game, and returns them as structured data. Dispatched by `/charter` and `/nightmare-headline`. It generates charters and runs nothing.
- **[`explorer`](agents/explorer.md)** — runs one budgeted exploratory session per charter against a running app, applies named heuristics, judges results with oracles, records an SBTM session sheet, and returns structured findings. Operates under an absolute safety boundary — it exercises the app but never runs destructive commands and never touches production or unauthorized systems. Dispatched by `/explore`.

## How this relates to `stride-gemini`

[`stride-gemini`](https://github.com/cheezy/stride-gemini) covers the Stride **task lifecycle** (claiming, hook execution, completion), and [`stride-gemini-ideation`](https://github.com/cheezy/stride-gemini-ideation) covers turning a fuzzy idea into a requirements doc. This extension covers **exploratory testing** — discovering the risks and bugs that scripted checks miss. A typical loop ships a feature with `stride-gemini`, then explores it here before calling it done.

## Sources & attribution

This extension packages **established exploratory-testing practice** — the accumulated craft of the context-driven testing community — into a form a Gemini CLI agent can apply. It invents no new method; it stands on decades of published work. The primary source is exploratory testing as a discipline: test design, execution, learning, and steering happening together, a framing owed to **Cem Kaner**, who coined the term. Specific models this extension leans on, with credit:

- **Session-Based Test Management (SBTM)** and the **PROOF** debrief mnemonic — **James Bach** and **Jonathan Bach**. The session sheet, Task Breakdown Metrics, and time-boxed session discipline in the `session` skill derive from SBTM.
- **Tours** — **James Whittaker** (*Exploratory Software Testing*). The tours grouped by tourist district in the `heuristics` skill are his.
- **Heuristic Test Strategy Model (HTSM)** — **James Bach**. The SFDIPOT coverage lens (in `chartering`) and the quality-criteria checklist (in `oracles`) come from the HTSM.
- **Bug advocacy and RIMGEA** — **Cem Kaner**. The Replicate / Isolate / Maximize / Generalize / Externalize / And-say-it-clearly follow-through in the `bug-advocacy` skill, and the principle that severity is a property of the failure rather than a scheduling decision, are his.

Where these skills quote or paraphrase, they use short, fair-use snippets and point back to the original work. Please consult the primary sources for the full treatment.

## License

MIT — see [LICENSE](LICENSE).
