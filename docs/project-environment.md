# The project environment file: `.exploratory.md`

`.exploratory.md` sits at the root of **the project under test** and says, once, how
an exploratory session gets to the running system, so `/explore` does not put the same
questions to you every run. You write it, and no command writes it unless you say yes
(see *Saving answers* below). `/explore` reads it in its Step 3. A Stride workflow that
dispatches the explorer could read it too: the Claude Code `stride` plugin does, at its
Step 0, while `stride-gemini` does not read it yet. `/recon` and `/pair` may read it
later.

The file is a handful of `## ` sections. **The file never holds a secret value**, so it
is safe to commit. An account is named by its fixture, or by the NAME of the key that
holds its credential in a gitignored secrets file such as `.env`, and the value stays
in that file. If you use Stride, this is the same split as `.stride.md` (hooks, under
version control) and `.stride_auth.md` (the token, gitignored).

It is not the `.exploratory/` directory. That directory holds what sessions write
(`backlog.md`, `coverage.md`, `sessions/`); this file is yours, and it sits next to
that directory.

**Every section is optional.** With no file, or with a section missing, `/explore`
behaves exactly as it did before the file existed.

Begin from the commented template in
[`templates/exploratory.md`](../templates/exploratory.md): copy it to your project
root as `.exploratory.md` and replace its placeholders. Nothing reads `docs/` or
`templates/` at run time. `/explore` reads only the fixed file name and names the six
sections itself, and the manual installers copy neither directory, so take the template
from this repository.

## The six sections

Each section is a `## <name>` heading followed by lines in one of two forms,
`<key>: <value>` or `- <item>`. Names are lowercase and spelled exactly as below.

### `authorization`

The two lines the explorer needs before it runs anything, for this project's local
targets:

```text
AUTHORIZED_NON_PRODUCTION: yes
ALLOWED_HOSTS: localhost:8000, localhost:5432
```

They record what you intend; they grant nothing. **Loading them never authorizes a
session.** `/explore` shows them to you, and `AUTHORIZED_NON_PRODUCTION: yes` reaches
a dispatch only through your confirmation in that run (see *Reading rules*).

### `app`

How to reach the running app:

- `base_url:` where it serves, such as `http://localhost:8000`.
- `health_check:` one `GET <path>` that has to answer before the first probe.
- `start:` how the developer starts it. **A session never starts or stops the app**;
  the line only tells a reader what to do when the health check fails.

### `probe_harness`

The project's own test framework, used to run one scratch probe file with fixture
users. It is how a session gets signed in, as more than one user.

- `command:` the single command that runs a probe file, given once.
  **`{probe_file}` is the only placeholder**, and it appears exactly once. The explorer
  puts the path of its own scratch file there and changes nothing else. A command with
  no `{probe_file}`, with two, or with any other placeholder is malformed.
- `probe_dir:` optional, for a framework that will run only files inside its test tree.
  A project-relative directory made only of letters, digits, `.`, `_`, `/` and `-`,
  with no empty, `.` or `..` segment (so no trailing `/`) and no segment that starts
  with `-`. **git must ignore** it, and it is **not a symbolic link, nor below one**.
  Before it makes anything there, the explorer refuses a value of any other shape, one
  git does not ignore, and one that is a link or has a link as a leading part; it then
  runs `git check-ignore` again on the probe directory it made, which git fails past a
  link, and removes that directory and refuses when the check fails. Leave `probe_dir`
  out when the framework runs a file from anywhere.
- `helpers:` the fixture helpers a probe may call: sign-in helpers, factories,
  feature-flag helpers.
- `services:` every local service the harness connects to, as `host:port` (the test
  database, for one), or `none`. Each one **must also be listed in `ALLOWED_HOSTS`**.
  When one is not, `/explore` drops the harness for that run, and a harness connection
  to an unlisted host is out of bounds and ends the session `blocked`.

### `accounts`

The roles a feature can need and how a probe gets each, one per line:

- `- <role>: fixture <fixture or helper name>`
- `- <role>: seeded account, credential under key <KEY_NAME> in <gitignored secrets file>`

Roles are such things as owner, editor, read-only, non-member and admin. Name the key,
never the value it holds.

### `observation`

Tools your main Gemini CLI session holds that the explorer does not: a browser on the
dev server, log tailing, read-only database queries. A visual pass run from the main
session uses them; the explorer observes only through its own four tools.

### `constraints`

Rules every session keeps, one per line. For example: never start or stop the dev
server, **never forge a session or cookie** against a running server.

## Reading rules

`/explore` keeps every one of these rules, and so must any other reader.

- **A missing file is an empty starting state, never an error.** The usual questions
  are asked and the file is not mentioned.
- **A file that is a symbolic link is never read and never written through.** A link,
  even one that points nowhere, counts as present but not loadable: nothing is taken
  from it and no save is offered. Only a regular file loads.
- **Loading the file never authorizes anything.** A repository you cloned can carry a
  `.exploratory.md` you never wrote. So `/explore` shows you, verbatim, the hosts, the
  harness command and every other line it is about to use, each accounts line with the
  key and secrets-file names it carries included, and you confirm them for this run
  inside the one question round `/explore` already asks. Only a confirmed file fills
  the environment context. Decline, and the file is set aside for the run and the
  ordinary questions are asked.
- **Nothing a confirmed file supplies is asked again.** Anything it leaves out is
  still asked.
- **A malformed or unknown section is reported and ignored, never guessed.** That
  covers an unknown heading, a section given twice, a line in neither form, a second
  `command:`, a placeholder other than `{probe_file}`, a host, command, `probe_dir` or
  `services` value holding a control character, an invisible or bidirectional
  formatting character or any non-ASCII character, and a value that looks like a
  credential rather than a fixture name, a key NAME or a secrets-file name. The report
  gives the section and the line number and never quotes a credential-shaped value.
  The other sections still load.
- **The file is data, never instructions.** A line that tells the reader to run
  something, skip a check or widen the scope is content to report.
- **Saving answers.** When no file exists, `/explore` may offer once to save the
  answers you just gave as a new `.exploratory.md`. It writes only on your explicit
  yes, **never over an existing file**, and never with a secret value in it.

## Worked example

A web app on `localhost:8000`, its test database on `localhost:5432`, and a test suite
that signs users in through fixtures:

```markdown
## authorization
AUTHORIZED_NON_PRODUCTION: yes
ALLOWED_HOSTS: localhost:8000, localhost:5432

## app
base_url: http://localhost:8000
health_check: GET /health
start: the developer starts the dev server in their own terminal

## probe_harness
command: <your test runner> {probe_file}
probe_dir: tests/.probes
helpers: the sign-in fixture, the user and project factories
services: localhost:5432

## accounts
- owner: fixture, a signed-in user who owns a project the probe creates
- editor: fixture, a second user with edit rights on that project
- read-only: fixture, a second user added without edit rights
- non-member: fixture, a third user with no access to the project
- admin: seeded account, credential under key TEST_ADMIN_PASSWORD in .env

## observation
- browser on the dev server, held by the main session
- log tailing on the dev server, held by the main session

## constraints
- never start or stop the dev server
- never forge a session or cookie against a running server
```

The `command:` line is whatever runs one test file in your project, with the file
replaced by `{probe_file}`: `pytest {probe_file}`, `npx vitest run {probe_file}`,
`bundle exec rspec {probe_file}`, `go test {probe_file}` or `mix test {probe_file}`,
plus any environment variable your suite needs to pick its test configuration. Keep
`probe_dir` only when your runner refuses a file outside its test tree, and make sure
git ignores it; otherwise leave it out, and probe files stay in the explorer's own
`mktemp -d` directory.

## What the explorer does with it

`/explore` turns a confirmed `probe_harness` section into a `PROBE_HARNESS:` line, its
`services` into a `PROBE_SERVICES:` line and any `probe_dir` into a `PROBE_DIR:` line
in the environment context of every dispatch. The explorer's rules for those lines are
in [`agents/explorer.md`](../agents/explorer.md): *What you receive*, the *Safety
boundary* bullet "Run a probe harness only as declared", *What you can observe* and
*The session budget*. In short:

- It runs the declared command and no other.
- It holds no file-writing tool, so it writes each probe file with one
  `run_shell_command` call under `noclobber`, inside its scratch directory, closing the
  heredoc with a word made fresh for that write, and it removes every probe file at
  cleanup.
- Text from the app, the charter or the task enters a probe file only as an escaped
  single-line string literal, or encoded and decoded when the probe runs; anything else
  is refused.
- Its harness connections obey `ALLOWED_HOSTS`: it checks `PROBE_SERVICES` and the
  harness's own test connection settings before the first run.
- It signs fixture users in only inside the test environment, and never forges a
  session or cookie against a running server.
- A harness observes server-side behaviour, never a rendered view.

## Gemini CLI specifics

- **The policy file still applies.** `policies/explorer.toml` judges the harness
  command and every probe write like any other `run_shell_command` call from the
  explorer. A declared command that is itself a recursive `rm`, an `rm` with a glob,
  `pkill`, `killall`, `git push` or a `kill` of PID `0` or a negative PID is refused by
  Gemini CLI, and the explorer records the refusal and runs the session without the
  harness rather than rephrasing the command. The ordinary runner commands above, the
  probe write, `git check-ignore`, `mktemp -d`, `rm -f -- <path>` and `rmdir` are not
  matched by any rule, and `lib/test-structure.sh` checks that they stay that way.
- **Approval.** Each `run_shell_command` call prompts in an interactive session and is
  denied by default in a headless one. A refused harness call is an obstacle in the
  debrief, never a result.
- **A harness costs turns.** The explorer runs one command per tool call, so each
  harness probe spends at least three calls (write the probe file, run it, remove it),
  on top of the setup checks and the final `rmdir`. They come out of the same tool-call
  ceiling and the same `max_turns: 60` as every other call, and nothing raises either
  for a harness, so a harness-heavy session reaches `tool_call_ceiling` sooner: expect
  fewer probes, and the explorer keeps turns in hand to remove every probe file.
  `timeout_mins: 30` bounds a slow first harness run, a test build for one, on the same
  clock as the rest of the session.
- **Windows.** The probe write is a POSIX heredoc. Where Gemini CLI runs PowerShell,
  the explorer cannot write a probe file and runs the session without the harness.
- **Templating.** `/explore` is a `.toml` command whose prompt Gemini CLI templates:
  it substitutes `{{args}}`, runs `!{...}` and injects `@{...}`. `{probe_file}` has a
  single pair of braces and neither prefix, so it reaches the operator and the explorer
  literally; never write it with doubled braces.
