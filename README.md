# njslyr7

A minimal orchestration layer for spawning long-running peer Claude Code
workers in sibling tmux panes. Ships as the `formation` CLI and a Claude Code
skill that knows when and how to use it.

## Why this exists

`multi-agent-njslyr` (v6) grew into a heavyweight system: 8-agent fixed
formation, YAML task queues, guardian scripts, per-CLI instruction variants,
secondary dashboards. It worked, but the ceremony outweighed the payoff for
most day-to-day tasks.

The catalyst for the rewrite was a PRS-LLM-dev session in April 2026 where
an ad-hoc three-pane mini-system — just a shared mailbox file and a couple
of bash helpers — solved a multi-hour task cleanly. That experiment made the
heavier v6 machinery feel like overkill for the same shape of problem.

`njslyr7` is the distillation: keep the protocols that matter (observability,
peer messaging, phone-based human-in-the-loop), drop everything the official
Claude Code primitives (`Task`, `TaskCreate`, `ScheduleWakeup`, `Memory`)
already provide.

## What you get

- `bin/formation` — one CLI with seven subcommands:
  `spawn | msg | status | inbox | reap | report | done | ask`
- `lib/mailbox.sh` — jsonl append-only inter-pane message bus with per-
  recipient cursor, flock-guarded writes.
- `lib/wake.sh` — `tmux send-keys` + `paste-buffer` helpers.
- `skills/formation/SKILL.md` — Claude Code skill with when-to-use criteria
  and invocation flow.
- `skills/formation/templates/briefing.md` — contract template between lead
  pane and worker pane.

Total: roughly 300 lines.

## When to reach for it

A worker costs you a fresh Claude Code process, a pane split, and a few
seconds of bootstrap. That cost is only worth paying when the task will run
for **minutes to hours** and you want one or more of:

- Live observability (tail the pane while the worker works)
- Mid-flight redirection (`formation msg worker-1 "actually, use approach B"`)
- Phone-based human-in-the-loop: worker pings you on LINE, you reply via
  `/remote-control` (alias `/rc`) from the Claude mobile client

For anything shorter, use the built-in `Task` tool instead.

## Install

```bash
git clone https://github.com/<you>/njslyr7.git ~/projects/njslyr7
cd ~/projects/njslyr7
bash install.sh
```

`install.sh` symlinks `bin/formation` into `~/.local/bin` and `skills/formation`
into `~/.claude/skills`, and creates the runtime state directory at
`~/.njslyr7/` (git-ignored mailbox + registry).

Re-run `install.sh` after pulling updates; it's idempotent.

## Usage

```bash
# From the lead pane:
formation spawn ./briefing.md worker-1   # split pane, launch claude, paste briefing
formation status                         # list workers + last pane line
formation msg worker-1 "use approach B"  # send instruction
formation inbox                          # read unread worker reports
formation reap worker-1                  # close pane and drop registry row

# From inside a worker's claude (via Bash tool):
formation report "phase 1 done, starting phase 2"
formation ask "schema migration or dual-write? need decision"
formation done "shipped. PR #42, tests green."
```

Each worker's claude is launched with `--session-name formation-<id>`, so
you can `/remote-control` to it from phone or web.

## Design invariants

- **Memory MCP is shared** between lead and workers. Workers should namespace
  their entries under `formation/<worker_id>/` to avoid stomping the lead.
- **CWD is inherited.** No cross-project spawning in v1.
- **Observer privilege.** `~/.njslyr7/mailbox/log.jsonl` is plain-text jsonl.
  Tail it to watch all formation traffic live. Credentials must be prefixed
  `[CONFIDENTIAL]` — hook for future opt-in encryption.
- **Sanada / Matsuoka** (backup-before-destructive, no-retreat) live in the
  user's global `~/.claude/CLAUDE.md`. njslyr7 assumes those are in force and
  does not re-state them.

## Status

v0.1 — functional but un-dogfooded. `wake.sh` ssh fallback and lead-side
inbox auto-poll are v2.

See `docs/spec.md` for the full design rationale, including what was
deliberately dropped from v6.
