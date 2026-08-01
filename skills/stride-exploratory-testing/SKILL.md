---
name: stride-exploratory-testing
description: Use when you want to test software the way a skilled human tester does — discovering risks, questions, and bugs that scripted or automated checks miss. This is the front door to the stride-exploratory-testing Gemini CLI extension — it teaches the mental model (Tested = Checked + Explored), frames a time-boxed session, and routes each request to the right sub-skill (chartering, heuristics, oracles, bug-advocacy, session) or TOML slash command (/charter, /nightmare-headline, /explore, /pair, /recon, /debrief, /harden). Invoke it when the user asks to "explore", "poke at", "do exploratory/manual testing on", "find bugs in", "charter a session for", or otherwise investigate a feature rather than confirm a known expectation.
skills_version: "1.0"
---

# stride-exploratory-testing

This is the orchestrator skill — the extension's front door. It teaches the exploratory-testing (ET) mental model and **routes** each request to the sub-skill or command that does the deep work. Keep it thin: the doctrine lives here so every session is framed the same way; the reusable depth (cheat sheets, oracle catalogs, session lifecycle) lives in the sub-skills this table points to.

Exploratory testing is not a fallback for "when there's no time to automate." It is a distinct, disciplined activity: **simultaneous test design, test execution, learning, and steering** (Kaner). The tester designs the next test from what the last one just revealed, and keeps steering toward risk. This skill exists so the agent applies that discipline coherently instead of poking at a feature ad hoc.

## The mental model

**Tested = Checked + Explored.**

- **Checking** is confirmation: evaluating a *known* expectation with an algorithmic decision rule. Automated tests, assertions, and "does the happy path still work" are checks. Machines are excellent at checking.
- **Exploring** is investigation: discovering the expectations you didn't know to write down — the risks, the surprising states, the questions no one asked. Checks tell you the product does what you expected; exploration tells you what you *should have* expected.

A product with a green test suite is *checked*, not *tested*. This extension supplies the "explored" half.

Exploration is a **simultaneous** loop, not a phase:

1. **Design** the next probe from what you know so far.
2. **Execute** it against the running system.
3. **Learn** from what actually happened (an oracle tells you whether it's interesting).
4. **Steer** — feed that learning back into the next design, moving toward the areas of highest risk.

## The five engines

Every exploratory session runs on five engines. Each sub-skill deepens one or more of them:

| Engine | What it does | Where the depth lives |
|---|---|---|
| **Charters** | Give the session a mission: what to explore, with what resources, to discover what information. | `chartering` skill, `/charter`, `/nightmare-headline` |
| **Observation** | Noticing what the system actually did — not what you expected. Fed by oracles. | `oracles` skill |
| **Variables** | The factors you can deliberately vary — data, state, sequence, timing, environment, configuration. | `heuristics` skill (variable catalog) |
| **Oracles** | How you decide something is *wrong* — consistency heuristics, references, claims, user expectations. | `oracles` skill |
| **Heuristics** | Idea generators that get you unstuck — cheat sheets, Tours, SFDIPOT, and other lenses. | `heuristics` skill (SFDIPOT lives in `chartering`) |

Two skills sit **around** that loop rather than inside it. `session` is the container that makes a run reportable — the lifecycle, the notes, the debrief, and the artifacts it leaves on disk. `bug-advocacy` picks up where the oracles stop: once a result is judged a defect, it owns the RIMGEA follow-through and the severity rubric that turn it into a report someone acts on.

## The session lifecycle (time-boxed)

Exploration is managed as **time-boxed sessions** (Session-Based Test Management, ~60–120 min of uninterrupted, chartered, reviewable work — that is the **human** box; an agent-run session is bounded by a probe budget instead, see the `session` skill). One session runs:

1. **Charter** — state the mission before touching the system.
2. **Recon** — a quick pass to learn the landscape and refine the charter.
3. **Explore** — the design/execute/learn/steer loop, driven by heuristics and judged by oracles.
4. **Note** — capture findings, bugs, questions, and new charter ideas *as you go*.
5. **Debrief** — review what was covered, what was found, and what's still at risk.

The `session` skill owns this lifecycle end to end; the `/explore` command runs it plan-and-execute in one shot.

## When to invoke

- The user asks to "explore", "poke at", "kick the tires on", "manually test", or "find bugs in" a feature.
- A change is risky, novel, or hard to fully specify, and green automated checks aren't enough confidence.
- The user wants a **charter** for a testing session, or wants to frame *what* to test before testing it.
- Someone asks "what could go wrong here?" / "what haven't we thought of?" about a feature or change.
- A bug was found and the user wants to investigate its neighborhood for related problems.

## When NOT to invoke

- The user wants to **write or fix an automated test** (a check) — that's a coding task, not exploration. Use the project's testing skills.
- The expectation is fully known and the ask is "confirm X still works" — that's checking; a scripted test is the right tool.
- The user is mid-implementation and needs the code changed, not investigated.
- There is no running system (or realistic stand-in) to explore — exploration needs something to observe.

## Routing table

Match the user's request to the right destination. The orchestrator frames and routes; it does not duplicate the sub-skills' content. The seven slash commands are native Gemini CLI commands authored as TOML under `commands/` (`commands/charter.toml`, `commands/nightmare-headline.toml`, `commands/explore.toml`, `commands/pair.toml`, `commands/recon.toml`, `commands/debrief.toml`, `commands/harden.toml`).

| The user wants to… | Route to |
|---|---|
| Frame a mission / decide *what* to test / write a charter | **`chartering`** skill |
| Enumerate targets systematically / apply SFDIPOT | **`chartering`** skill (SFDIPOT lens) |
| Generate a risk-driven charter from "what's the worst that could happen" | **`/nightmare-headline`** command |
| Create one or more charters interactively | **`/charter`** command |
| Get unstuck / generate test ideas / apply a cheat sheet or a Tour | **`heuristics`** skill |
| Know the factors to vary (data, state, sequence, environment) | **`heuristics`** skill (variable catalog) |
| Decide "is this actually a bug?" / apply consistency oracles | **`oracles`** skill |
| Turn a confirmed defect into a report someone will act on / rate its severity | **`bug-advocacy`** skill |
| Run a full time-boxed session with notes and a debrief | **`session`** skill |
| Do a quick reconnaissance pass over an unfamiliar feature | **`/recon`** command |
| Run an exploratory session end-to-end (plan and execute) | **`/explore`** command |
| Test alongside a human who is driving the app themselves | **`/pair`** command |
| Turn a session's findings into regression checks / "make sure this bug can't come back" | **`/harden`** command |
| Close out a session and produce a structured debrief | **`/debrief`** command |

Two custom agents support the commands rather than being invoked directly: **`charter-generator`** (turns a target + risk into candidate charters) and **`explorer`** (executes a charter's exploration loop and reports findings). Reach for the commands above; they dispatch these agents for you.

## Running the app under the Gemini CLI

Where a command or the `explorer` agent exercises the running app, the Gemini CLI drives the shell through `run_shell_command`, **one command at a time** — not a chained script. Design each probe as a single command, observe its result, then decide the next one. This keeps the design/execute/learn/steer loop honest (you judge each result before the next probe) and keeps the session inside its safety boundary: exercise and observe the app, **never** run destructive or production-mutating commands, and never touch production or unauthorized systems.

## Doctrine, and the supplementary lenses

The **authoritative doctrine** of this extension is the established exploratory-testing canon: the essential elements (charters, time-boxed sessions, simultaneous design/execute/learn/steer), integrating exploration throughout the work, exploring early and often, and knowing when you have explored *enough*. Hold that as the spine.

The richer models the sub-skills provide are **lenses, not laws** — reach for them when they help, drop them when they don't:

- **SBTM** (Session-Based Test Management) — the charter → session → debrief management frame used above.
- **Tours** — themed walkthroughs (the money tour, the landmark tour, the back-alley tour…) that bias exploration toward a particular kind of risk. Cataloged in `heuristics`.
- **SFDIPOT** (Structure, Function, Data, Interfaces, Platform, Operations, Time) — a coverage heuristic for making sure you looked at the whole product. Cataloged in `chartering`.

Use them as idea generators feeding the design/execute/learn/steer loop — never as a script to march through.

## Integrate exploration throughout

Exploration is not a gate at the end. **Explore early and often:** a short recon session on a rough feature surfaces risk while it's still cheap to act on; a session against a finished feature catches what the checks assumed away. Interleave exploration with development and with the automated checks — each informs the other. A charter that keeps discovering new questions means there is more risk to chase; a charter that stops surfacing anything new is your signal that you have explored *enough* for now, and it's time to charter the next area or hand off.
