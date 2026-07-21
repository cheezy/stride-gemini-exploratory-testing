# Stride Exploratory Testing for Gemini CLI

Skilled, human-style exploratory testing — from Gemini CLI.

> **Scaffold skeleton.** This README is filled in by a later task (docs & fixtures).

This extension provides exploratory-testing commands, skills, and custom agents for
projects that use [Stride](https://www.stridelikeaboss.com). It is the Gemini CLI
port of [`cheezy/stride-exploratory-testing`](https://github.com/cheezy/stride-exploratory-testing)
(Claude Code). Charter a session for a target, run a time-boxed exploratory session
against a running app, and produce a stakeholder-ready debrief — discovering the
risks and bugs that scripted or automated checks miss (Tested = Checked + Explored).

> **GitHub Topic:** This repo should be tagged with `gemini-cli-extension` for
> auto-indexing in the Gemini extension gallery.

## Commands

Native slash commands (authored as TOML in `commands/`):

```text
/charter              Turn a target into a ranked list of exploratory-testing charters.
/nightmare-headline   Risk-brainstorm the worst headline, then turn it into charters.
/explore              Plan and run exploratory testing end to end, then debrief.
/recon                Reconnaissance pass over an unfamiliar system before chartering.
/debrief              Turn raw session notes into a stakeholder-ready debrief.
```

## License

MIT — see [LICENSE](LICENSE).
