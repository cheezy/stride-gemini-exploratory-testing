# Stride Exploratory Testing for Gemini CLI

> **Scaffold skeleton.** This context file is filled in by a later task. It will
> orient the Gemini CLI agent on the plugin's mental model (Tested = Checked +
> Explored), its skills, its custom agents, and its TOML slash commands.

Test software the way a skilled human tester does — discovering risks, questions,
and bugs that scripted or automated checks miss. This extension is the Gemini CLI
port of [`cheezy/stride-exploratory-testing`](https://github.com/cheezy/stride-exploratory-testing)
(Claude Code). The companion [stride-gemini](https://github.com/cheezy/stride-gemini)
extension covers the Stride **task lifecycle** (claiming, hooks, completion).

## Commands

Native slash commands (authored as TOML in `commands/`) drive the workflow:
`/charter`, `/nightmare-headline`, `/explore`, `/recon`, `/debrief`.

## Skills

The knowledge core lives under `skills/`: the `stride-exploratory-testing`
orchestrator plus `chartering`, `heuristics`, `oracles`, and `session`. The
`heuristics` skill is the single canonical catalog; `HEURISTICS.md` at the root is
a one-page pointer into it.

## Custom Agents

`charter-generator` (read-only; produces ranked charters) and `explorer` (runs one
time-boxed session per charter against a running app, under an absolute safety
boundary, and returns structured findings).
