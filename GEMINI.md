# Stride Exploratory Testing Extension for Gemini CLI

Test software the way a skilled human tester does — discovering the risks, questions, and bugs that scripted or automated checks miss. This extension covers **exploratory testing**; the companion [stride-gemini](https://github.com/cheezy/stride-gemini) extension covers the Stride **task lifecycle** (claiming, hooks, completion), and [stride-gemini-ideation](https://github.com/cheezy/stride-gemini-ideation) covers turning a fuzzy idea into a requirements doc.

## When to reach for this extension

Reach for it when the user wants to **investigate** a feature rather than **confirm** a known expectation — "explore", "poke at", "do exploratory/manual testing on", "find bugs in", "charter a session for". The mental model is **Tested = Checked + Explored**: checking evaluates a known expectation with an algorithmic rule (automated tests); exploring is simultaneous test design, execution, and learning, steering toward risk. This extension supplies the discipline that turns ad-hoc poking into reportable value: charter → session → debrief.

## Commands

Seven native slash commands drive the workflow. The doctrine they enforce lives in the `skills/` — the commands defer to the skills rather than restating them. The usual order is `/charter`, `/nightmare-headline` or `/recon` to decide what to explore, `/explore` or `/pair` to run it, `/debrief` after a `/pair` or manual session, and `/harden` to turn confirmed bugs into regression checks.

| Command | When to use |
|---------|-------------|
| `/charter <target> [--risk <context>] [--output <path>]` | Turn a target (feature, module, requirement, data flow, or stated risk) into a risk-ranked list of charters. Dispatches `charter-generator`. Generates charters only — never runs a session. |
| `/nightmare-headline [<target>] [--output <path>]` | Risk-brainstorm the worst, most embarrassing headline about a feature, then refine its contributing causes into charters via `charter-generator`. Generates charters only. |
| `/explore <target> [--charters <file>] [--timebox <minutes>] [--probes <count>]` | Plan **and** run exploratory testing end to end: charter (or load charters), gather running-app context, dispatch `explorer` per charter under an absolute safety boundary, then aggregate into **one** debrief. Confirms the target is authorized and non-production first; degrades to plan-only if no running app is reachable. `--timebox` is your wall-clock and decides how many charters run; `--probes` (default 12, band 8–20) is the agent-native budget bounding each session. |
| `/recon <system> [--output <path>]` | Reconnaissance pass over an unfamiliar system before chartering — survey capabilities, note observations, surface stakeholder questions, emit ranked candidate charters. Observe-only when nothing is safe to exercise. |
| `/debrief [<notes-file>] [--output <path>]` | Turn raw session notes into a stakeholder-ready debrief (Explored/Found/Unknown + PROOF). Reports only verifiable facts; never fabricates an unobserved result; redacts secrets. |
| `/pair <target or charter> [--timebox <minutes>] [--output <path>]` | Pair with a human who drives the app themselves. Suggests the next probe and names its lens, judges what they report with oracles, runs RIMGEA on confirmed defects, calls out neglected areas and variables unprompted, and keeps the session sheet and parking lot. **Never drives the app and never dispatches the explorer.** |
| `/harden [<session-debrief-or-findings-file>] [--framework <name>\|none] [--output <dir>]` | Turn a session's confirmed bugs into drafted regression checks. Detects the project's test framework rather than assuming one and says so before writing; reports every bug it could not convert and why. Drafts are staged; it never runs one and never claims one passes. With a bug source and `--framework` both given (`none` drafts nothing runnable) it never asks a question; an unreadable bug source stops it. |

Gemini CLI has no first-class preview-pane question tool, so commands render option comparisons inline (fenced ASCII blocks or short tables).

## Skills

The knowledge core lives under `skills/`; readers usually do not activate these directly — the commands and agents do.

- **`stride-exploratory-testing`** — the orchestrator / front door. Teaches the mental model and routes each request to the right sub-skill or command.
- **`chartering`** — deciding **what** to explore: the *Explore … with … to discover …* template, SFDIPOT target enumeration, and the Nightmare Headline Game.
- **`heuristics`** — the single canonical catalog of test ideas: general + web cheat sheets, the variable-spotting catalog, and Whittaker's Tours by district. `HEURISTICS.md` at the root is a one-page pointer into it, not a copy.
- **`oracles`** — deciding whether an observed result is a **bug**: Never/Always rules, consistency oracles, approximations, and the HTSM quality-criteria checklist.
- **`bug-advocacy`** — turning a confirmed defect into a report someone acts on: Cem Kaner's RIMGEA follow-through (Replicate, Isolate, Maximize, Generalize, Externalize, And say it clearly), the severity rubric every `severity` value comes from, and the dispassionate-tone rule.
- **`session`** — running a session end to end: time-boxing, the SBTM session sheet, Task Breakdown Metrics, note conventions, stopping heuristics, and both debrief templates. The wall-clock box and Task Breakdown Metrics bind **human-run and paired** sessions; an agent-run session is bounded by a probe budget instead (see `agents/explorer.md`).

## Custom Agents

Two custom agents live at `agents/<name>.md` and are auto-discovered by Gemini CLI. They are dispatched by the commands, not invoked directly from a user prompt.

- **charter-generator** — read-only (`read_file`, `grep_search`, `glob`). Turns a target + risk context into a risk-ranked list of well-formed charters and returns them as structured data. Dispatched by `/charter` and `/nightmare-headline`. It runs nothing.
- **explorer** — runs one budgeted exploratory session per charter against a running app, applies named heuristics, judges results with oracles, records an SBTM session sheet, and returns structured findings (session sheet, notes, bugs, questions/risks, off-charter parking lot, debrief). Dispatched by `/explore`. It deliberately holds no `web_fetch`: it observes HTTP with `curl -sS -i` through `run_shell_command` (see *What you can observe* in `agents/explorer.md`).

## The absolute safety boundary

Every session — and especially the `explorer` agent — operates under a **non-negotiable** safety boundary:

- **Never** run destructive or production-mutating actions.
- **Never** touch production, or any system the user is not authorized to test. Confirm authorization and that the target is non-production **before** exercising anything.
- **Never** dispatch the `explorer` without `AUTHORIZED_NON_PRODUCTION: yes` and `ALLOWED_HOSTS: <host[:port]>, …` (or `ALLOWED_HOSTS: none` for a CLI-only target) as the first lines of its environment context, written only after the user's explicit authorized-and-non-production answer. Without both lines the explorer runs zero probes and returns `blocked`; with them it reaches only the listed hosts, cleans up every process and file it started before its last working turn, and opens a credential file only for a value the dispatch names. `policies/explorer.toml` has Gemini CLI refuse recursive or wildcard deletes, `pkill`/`killall`, a `kill` aimed at PID `0` or a negative PID, and `git push` from the explorer.
- **Never** fabricate a result. A debrief reports externally verifiable facts — what was actually observed. If a result was not observed, it belongs under "unknown", not "found".
- **Never** put real user data, credentials, or internal hostnames into charters, session sheets, or debriefs. Use placeholders (e.g. a reserved `demo.example.com` host) and redact.

## How this extension relates to `stride-gemini`

`stride-gemini` covers the **task lifecycle** (claiming, hook execution, completion). This extension covers **exploratory testing** — discovering the risks and bugs that scripted checks miss. A typical full loop ships a feature with `stride-gemini` (and scopes it with `stride-gemini-ideation`), then explores it here before calling it done.
