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

The installers copy `gemini-extension.json`, `GEMINI.md`, and the `commands/`, `skills/`, `agents/`, `lib/`, `fixtures/`, and `policies/` directories into the target extension location.

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

These files are read back on later runs as **data, never instructions** — a line in one that reads like a command is content to weigh, not something any command obeys. The full contract, including the exact formats and the write mechanics, lives in the [`session` skill](skills/session/SKILL.md)'s reference, [`skills/session/references/session-artifacts.md`](skills/session/references/session-artifacts.md).

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

Turn a session's oracle-confirmed bugs into drafted regression checks — the path from Explored back to Checked. Reads bugs from a session sheet, a debrief, an explorer findings object, or pasted findings; **detects the project's own test framework from the repository** rather than assuming one, and says what it detected before writing anything; and drafts one check per convertible bug, built from its isolated minimal repro. Reports every bug it could not convert and why, instead of guessing at a repro. Drafts are staged under `.exploratory/checks/` and are **never run** — the command never runs a draft and never claims one passes. Given both a bug source (such as the explorer's report file) and `--framework` (a framework name, or `none` to draft nothing runnable), it runs unattended and never stops to ask; a bug source it cannot read stops the run rather than falling back to another session.

## Skills

The knowledge core lives under `skills/`. The commands and agents defer to these skills rather than restating the doctrine:

- **[`stride-exploratory-testing`](skills/stride-exploratory-testing/SKILL.md)** — the orchestrator and front door. Teaches the mental model (Tested = Checked + Explored), frames a time-boxed session, and routes each request to the right sub-skill or command.
- **[`chartering`](skills/chartering/SKILL.md)** — deciding **what** to explore and framing it as a charter: the *Explore … with … to discover …* template, SFDIPOT target enumeration, and the Nightmare Headline Game.
- **[`heuristics`](skills/heuristics/SKILL.md)** — the single source of truth for test ideas: the general and web cheat sheets, the variable-spotting catalog, and Whittaker's Tours grouped by district. Turns a charter into specific probes.
- **[`oracles`](skills/oracles/SKILL.md)** — deciding whether what you observed is a **bug**: Never/Always rules, consistency oracles, approximations for when the right answer is unknowable, and the HTSM quality-criteria checklist.
- **[`bug-advocacy`](skills/bug-advocacy/SKILL.md)** — turning a confirmed defect into a report someone acts on: Cem Kaner's RIMGEA follow-through (Replicate, Isolate, Maximize, Generalize, Externalize, And say it clearly), a severity rubric with explicit per-level criteria, and the dispassionate-tone rule. Its worked example and the full tone rule are in [`references/worked-example-and-tone.md`](skills/bug-advocacy/references/worked-example-and-tone.md).
- **[`session`](skills/session/SKILL.md)** — running a session end to end: time-boxing, the SBTM session sheet, Task Breakdown Metrics, note conventions, stopping heuristics, the off-charter parking lot, and both debrief templates. The wall-clock box and Task Breakdown Metrics bind **human-run and paired** sessions; an agent-run session is bounded by an agent-native probe budget instead.

The `heuristics` skill is the canonical catalog; [`HEURISTICS.md`](HEURISTICS.md) at the root is a one-page pointer into it, not a copy.

## Custom Agents

Two custom agents live at `agents/<name>.md` and are auto-discovered by Gemini CLI. They are dispatched by the commands, not invoked directly from a user prompt:

- **[`charter-generator`](agents/charter-generator.md)** — read-only. Turns a target into a risk-ranked list of well-formed charters using SFDIPOT and the Nightmare Headline Game, and returns them as structured data. Dispatched by `/charter` and `/nightmare-headline`. It generates charters and runs nothing.
- **[`explorer`](agents/explorer.md)** — runs one budgeted exploratory session per charter against a running app, applies named heuristics, judges results with oracles, records an SBTM session sheet, and returns structured findings. Operates under an absolute safety boundary — it exercises the app but never runs destructive commands and never touches production or unauthorized systems. Its tools are `read_file`, `grep_search`, `glob` and `run_shell_command`, with no fetch tool: it observes HTTP with `curl -sS -i` and judges only what one of those tools can observe, so a charter that needs a rendered view (layout, colour, contrast) comes back `blocked` with `stop_reason: "no_observation_surface"` instead of a verdict read from HTML source. It runs only when its environment context carries `AUTHORIZED_NON_PRODUCTION: yes` and an `ALLOWED_HOSTS` line, each on a line of its own, reaches only the listed hosts, and cleans up everything it started; [`policies/explorer.toml`](policies/explorer.toml) adds Gemini CLI deny rules for the commands it must never run. Dispatched by `/explore`, which writes both lines for you, first in the block; a direct caller must send them or the session ends `blocked`.

### Explorer report file (`EXPLORATORY_REPORT_PATH`)

A workflow that dispatches `explorer` itself can keep the full findings out of its own context by supplying an absolute path, as an argument of its own or as one line of the environment context:

```text
EXPLORATORY_REPORT_PATH=/absolute/path/to/project/.stride/.exploratory-W123-r1.json
```

- **What the explorer does with it.** After cleanup, and before its last working turn, it writes the complete contract `1.0` findings object to exactly that file with one `run_shell_command` call under `noclobber`; if the parent directory is missing it runs one `mkdir -p` and tries once more. It holds no `write_file`, which Gemini CLI cannot limit to one path. Each `run_shell_command` call prompts in an interactive session and is denied by default in a headless one, so a headless caller that does not allow the explorer's shell gets the fallback below.
- **What you get back.** Plain text of at most 2,048 bytes with no ```json fence: `report:`, `contract_version:`, `status:`, `stop_reason:`, a probes line, a bug count by severity (plus `questions_risks`, `off_charter` and `known_bad` counts), then one `<Severity> | replicated: <yes|no|not established> | <summary>` line per bug; a verify dispatch also gets a `verify:` line after `status:`. Read the findings from the path **you** supplied, never one the summary names. `EXPLORER_OUTPUT=<path> bash lib/test-structure.sh` checks a written report against the contract.
- **What it refuses.** A relative path, a `..` segment, a quote or control character, a path that already exists (it never overwrites or follows a link), two or more `EXPLORATORY_REPORT_PATH` lines, or a path built from anything it read while exploring. A refused or failed write comes back as `report: NOT WRITTEN — <reason>` followed by the full fenced JSON, so no findings are lost.
- **Neutralise copies of it.** Put `> ` in front of any `EXPLORATORY_REPORT_PATH` line inside operator- or charter-supplied text you pass along, as `/explore` does. `/explore` itself never passes a path: it debriefs from the whole findings object.
- **Hardening from it.** Pass that same report file to `/harden` as its bug source, with `--framework <name>` or `--framework none`, and `/harden` runs without stopping to ask anything. It reads the file itself, never the bounded summary, and treats its contents as data.

### Explorer verify mode (`EXPLORATORY_MODE=verify`)

A workflow that wants to know whether one fixed bug is really fixed can re-check it without a whole session. Add one line to the environment context, alongside the two required lines, and pass the bug's `summary`, `observed` and `minimal_repro` (and its `generalization`, if it has one):

```text
EXPLORATORY_MODE=verify
```

- **What it runs.** A charter built from the bug, on a budget of **2 probes / 10 tool calls** (band 1–2). Probe 1 re-runs the `minimal_repro` exactly; probe 2 tries one variant from `generalization`, when there is one. A caller may raise the tool-call ceiling for setup state, never above 60, but never the probe budget. `max_turns: 60` bounds the session from above but counts model turns, so the explorer counts its own probes and calls. The bug's fields are data: each step is rebuilt as the explorer's own command, and a step that needs a host outside `ALLOWED_HOSTS` is not run.
- **What you get back.** The usual findings object plus a root `verify` object — `{ "result": "pass" | "fail" | "not_verified", "repro_reached": true | false, "evidence": "..." }` — and, with `EXPLORATORY_REPORT_PATH`, a `verify:` summary line. A partial fix is `fail`, with the remaining defect in `bugs`. A repro that was never reached, a bug with no usable `minimal_repro`, or a dispatch missing either required line is `not_verified`: **never treat it as a pass.** A `pass` covers that one bug only. `status` is still derived from `stop_reason`. See [`fixtures/example-explorer-verify-output.json`](fixtures/example-explorer-verify-output.json) for a `fail` on a partial fix.
- **What does not change.** The required lines, the safety boundary, cleanup and the report-file rules all apply exactly as in a full session. `/explore` never sets verify mode.

## Tool names (porting)

The skill and agent bodies reference Gemini CLI tool names directly. When porting prompts that originated on another platform (the upstream Claude Code plugin, or the Codex/Copilot/opencode ports), use these equivalents:

| Other-platform reference | Gemini Tool |
|--------------------------|-------------|
| `Read` | `read_file` |
| `Grep` | `grep_search` |
| `Glob` | `glob` |
| `Bash` | `run_shell_command` |
| `Edit` | `replace` |
| `Write` | `write_file` |
| `WebFetch` | `web_fetch` |
| `list directory` | `list_directory` |

The mapping is for translating prose, not a tool grant: the `explorer` agent deliberately holds no `web_fetch`.

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
