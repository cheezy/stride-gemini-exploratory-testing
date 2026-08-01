# Changelog

All notable changes to the Stride Exploratory Testing extension for Gemini CLI are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`interfaces` lens** — the Heuristic Test Strategy Model's **I**nterfaces element joins the coverage lens in the `chartering` skill, covering APIs, imports and exports, UI surfaces, and integration points between systems: the boundaries where service-oriented and LLM tool-calling applications most often fail. **Downstream consumers must handle `interfaces` as a new allowed value of a charter object's optional `lens` field** (`agents/charter-generator.md`), alongside the existing `structure`, `function`, `data`, `platform`, `operations`, and `time`.

### Changed

- **`SFDPOT` renamed to `SFDIPOT`** across the extension — skills, custom agents, TOML commands, `GEMINI.md`, `README.md`, and `HEURISTICS.md`. Bach's HTSM (v6.0, 2024) lists seven Product Elements; the six-letter `SFDPOT` the extension cited is a superseded form of the same heuristic. The `Interfaces` row slots between `Data` and `Platform`; no existing row was renamed, reordered, or dropped. The charter object's `source` enum value is still the literal `sfdpot` — it is a wire value, not the acronym, and renaming it would break existing consumers.
- **The `explorer` agent no longer reports numbers it cannot observe.** `session_sheet` drops `duration` and `tbs` (Task Breakdown Metric percentages) — a wall-clock measurement an agent has no way to take, whose presence contradicted the agent's own hard rule against fabricating a result. In their place it reports what it genuinely counts: `probe_budget`, `probes_attempted`, `probes_with_finding`, `on_charter_probes`/`off_charter_probes`, `tool_calls_used`, `heuristics_applied`, and `stop_reason`. An agent session is now bounded by an **agent-native budget** — a probe budget (default 12, band 8–20) and a tool-call ceiling (5 × the probe budget), whichever is reached first; the agent definition's own `max_turns` is a hard outer bound, so the effective ceiling is the lower of the two. The `session` skill keeps the 60–120 minute box and TBS for **human-run and paired** sessions and now states plainly that neither binds an agent session; the four stopping heuristics are unchanged in substance (bullet 2 now reads "The box or the budget is up"). **`/explore` gains `--probes <count>`** for the per-session probe budget; **`--timebox <minutes>` keeps its unit** and is now documented as doing only what it always effectively did — deciding how many charters run (one session ≈ 90 minutes) — and is never passed to the explorer. **Downstream consumers that read `session_sheet.duration` or `session_sheet.tbs` must switch to the counts**; `/debrief` is unaffected (it consumes unstructured tagged notes). `fixtures/example-session-sheet.md` and `fixtures/example-debrief.md` are now **agent-run** examples — a `SESSION BUDGET` block with probe and tool-call counts and a `stop_reason` in place of `DURATION` and `TASK BREAKDOWN METRICS` — so the extension ships a worked example of the new shape at the fixture `README.md` points `/explore` readers to. The `explorer` agent's `max_turns` rises from 40 to 60 so the runtime bound agrees with the default ceiling instead of silently capping it; the agent still stops at the lower of the two and reports it as `tool_call_ceiling`. `/explore` also gains the `--probes` flag in the `GEMINI.md` command table, which is the signature Gemini CLI auto-loads into every session.

## [0.1.0] - 2026-07-21

Initial scaffold of the Gemini CLI extension.

### Added

- **Extension skeleton** — `gemini-extension.json` manifest at the root (name `stride-gemini-exploratory-testing`, version `0.1.0`, `contextFileName` `GEMINI.md`), a `GEMINI.md` context-file skeleton, the `skills/`, `agents/`, `commands/`, `lib/`, and `fixtures/` directory skeleton, and `README.md` / `HEURISTICS.md` / `LICENSE` (MIT) skeletons. The skills, custom agents, TOML slash commands, smoke tests, and docs content are authored by subsequent tasks.
- **Install scripts & marketplace registration** — `install.sh` and `install.ps1` at the root that install the extension into `~/.gemini/extensions/stride-gemini-exploratory-testing/` (global, default) or `.gemini/extensions/…/` (with `--project` / `-Project`), copying the manifest, `GEMINI.md`, and the `commands/`, `skills/`, `agents/`, `lib/`, and `fixtures/` directories while preserving the `lib/*.sh` executable bit. Both recommend `gemini extensions install <repo-url>` as the preferred path. The extension is registered in the `stride-gemini-marketplace` catalog (`extensions.json`).
