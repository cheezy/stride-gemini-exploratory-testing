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

   `/explore` confirms the target is authorized and non-production, gathers the running-app context, dispatches the `explorer` agent for each charter under an absolute safety boundary, and aggregates every session into one debrief. The per-session record is an SBTM session sheet — see [`fixtures/example-session-sheet.md`](fixtures/example-session-sheet.md).
5. **Read the debrief.** You get an Explored/Found/Unknown summary, a PROOF review, a severity-ranked bug list, and a follow-up parking lot — see [`fixtures/example-debrief.md`](fixtures/example-debrief.md). To rebuild a debrief from raw notes later, run `/debrief`.

Not sure what to charter yet? Start with `/recon` to survey an unfamiliar system, or `/nightmare-headline` to brainstorm the worst plausible outcome and turn it into charters.

## Commands

Native slash commands, authored as TOML in `commands/`:

### /charter

Turn a target — a feature, module, requirement, data flow, or a stated risk — into a ranked list of well-formed exploratory-testing charters. Dispatches the `charter-generator` agent, renders the charters highest-risk-first, and optionally writes them to a file with `--output`. **Generates charters only** — it never runs a session.

### /nightmare-headline

Run the Nightmare Headline Game — a fast risk-brainstorm that turns "the worst, most embarrassing headline someone could write about this feature" into ranked charters. Elicits catastrophic headlines, picks one, brainstorms its contributing causes, and refines those causes into charters via the `charter-generator` agent. Generates charters only.

### /explore

Plan and run exploratory testing end to end against a target — generate charters (or load them with `--charters`), gather the running-app environment context, dispatch the `explorer` agent per charter under an absolute safety boundary, then aggregate every session into **one** debrief (Explored/Found/Unknown + PROOF + a severity-ranked bug list + a follow-up parking lot). Confirms the target is authorized and non-production before executing; degrades to plan-only when no running app is available.

### /recon

Run a reconnaissance session on an unfamiliar or existing system before chartering — survey its capabilities, note observations, surface the questions a stakeholder should answer, and emit ranked candidate charters. A quick landscape-mapping pass, not a full session; probes only systems you are authorized to test, and stays observe-only when there is nothing safe to exercise.

### /debrief

Turn raw exploratory-session notes and findings into a stakeholder-ready debrief report using the session skill's two templates — Explored/Found/Unknown and PROOF (Past/Results/Obstacles/Outlook/Feelings). Reports only verifiable facts, never fabricates an unobserved result, and redacts real credentials or private data from the notes.

## Skills

The knowledge core lives under `skills/`. The commands and agents defer to these skills rather than restating the doctrine:

- **[`stride-exploratory-testing`](skills/stride-exploratory-testing/SKILL.md)** — the orchestrator and front door. Teaches the mental model (Tested = Checked + Explored), frames a time-boxed session, and routes each request to the right sub-skill or command.
- **[`chartering`](skills/chartering/SKILL.md)** — deciding **what** to explore and framing it as a charter: the *Explore … with … to discover …* template, SFDPOT target enumeration, and the Nightmare Headline Game.
- **[`heuristics`](skills/heuristics/SKILL.md)** — the single source of truth for test ideas: the general and web cheat sheets, the variable-spotting catalog, and Whittaker's Tours grouped by district. Turns a charter into specific probes.
- **[`oracles`](skills/oracles/SKILL.md)** — deciding whether what you observed is a **bug**: Never/Always rules, consistency oracles, approximations for when the right answer is unknowable, and the HTSM quality-criteria checklist.
- **[`session`](skills/session/SKILL.md)** — running a session end to end: time-boxing, the SBTM session sheet, Task Breakdown Metrics, note conventions, stopping heuristics, the off-charter parking lot, and both debrief templates.

The `heuristics` skill is the canonical catalog; [`HEURISTICS.md`](HEURISTICS.md) at the root is a one-page pointer into it, not a copy.

## Custom Agents

Two custom agents live at `agents/<name>.md` and are auto-discovered by Gemini CLI. They are dispatched by the commands, not invoked directly from a user prompt:

- **[`charter-generator`](agents/charter-generator.md)** — read-only. Turns a target into a risk-ranked list of well-formed charters using SFDPOT and the Nightmare Headline Game, and returns them as structured data. Dispatched by `/charter` and `/nightmare-headline`. It generates charters and runs nothing.
- **[`explorer`](agents/explorer.md)** — runs one time-boxed exploratory session per charter against a running app, applies named heuristics, judges results with oracles, records an SBTM session sheet, and returns structured findings. Operates under an absolute safety boundary — it exercises the app but never runs destructive commands and never touches production or unauthorized systems. Dispatched by `/explore`.

## How this relates to `stride-gemini`

[`stride-gemini`](https://github.com/cheezy/stride-gemini) covers the Stride **task lifecycle** (claiming, hook execution, completion), and [`stride-gemini-ideation`](https://github.com/cheezy/stride-gemini-ideation) covers turning a fuzzy idea into a requirements doc. This extension covers **exploratory testing** — discovering the risks and bugs that scripted checks miss. A typical loop ships a feature with `stride-gemini`, then explores it here before calling it done.

## Sources & attribution

This extension packages **established exploratory-testing practice** — the accumulated craft of the context-driven testing community — into a form a Gemini CLI agent can apply. It invents no new method; it stands on decades of published work. The primary source is exploratory testing as a discipline: test design, execution, learning, and steering happening together, a framing owed to **Cem Kaner**, who coined the term. Specific models this extension leans on, with credit:

- **Session-Based Test Management (SBTM)** and the **PROOF** debrief mnemonic — **James Bach** and **Jonathan Bach**. The session sheet, Task Breakdown Metrics, and time-boxed session discipline in the `session` skill derive from SBTM.
- **Tours** — **James Whittaker** (*Exploratory Software Testing*). The tours grouped by tourist district in the `heuristics` skill are his.
- **Heuristic Test Strategy Model (HTSM)** — **James Bach**. The SFDPOT coverage lens (in `chartering`) and the quality-criteria checklist (in `oracles`) come from the HTSM.

Where these skills quote or paraphrase, they use short, fair-use snippets and point back to the original work. Please consult the primary sources for the full treatment.

## License

MIT — see [LICENSE](LICENSE).
