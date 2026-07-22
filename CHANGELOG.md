# Changelog

All notable changes to the Stride Exploratory Testing extension for Gemini CLI are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-21

Initial scaffold of the Gemini CLI extension.

### Added

- **Extension skeleton** — `gemini-extension.json` manifest at the root (name `stride-gemini-exploratory-testing`, version `0.1.0`, `contextFileName` `GEMINI.md`), a `GEMINI.md` context-file skeleton, the `skills/`, `agents/`, `commands/`, `lib/`, and `fixtures/` directory skeleton, and `README.md` / `HEURISTICS.md` / `LICENSE` (MIT) skeletons. The skills, custom agents, TOML slash commands, smoke tests, and docs content are authored by subsequent tasks.
- **Install scripts & marketplace registration** — `install.sh` and `install.ps1` at the root that install the extension into `~/.gemini/extensions/stride-gemini-exploratory-testing/` (global, default) or `.gemini/extensions/…/` (with `--project` / `-Project`), copying the manifest, `GEMINI.md`, and the `commands/`, `skills/`, `agents/`, `lib/`, and `fixtures/` directories while preserving the `lib/*.sh` executable bit. Both recommend `gemini extensions install <repo-url>` as the preferred path. The extension is registered in the `stride-gemini-marketplace` catalog (`extensions.json`).
