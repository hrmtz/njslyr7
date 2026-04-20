---
name: formation
version: 0.1.0
description: |
  Spawn a long-running peer Claude Code worker in a new tmux pane when a task
  justifies hours of wall time and needs live observability, mid-flight
  redirection, or phone-based human-in-the-loop acks. Use this when the Task
  tool's ephemeral subagent model is insufficient: specifically for work where
  the user wants to tail the worker's pane, send follow-up instructions, or
  approve decisions from a phone via /remote-control while away from the desk.
  NOT for quick lookups or single-shot research — use Task for those.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# formation — peer pane orchestration

A "worker" is a separate Claude Code CLI running in its own tmux pane, seeded
with a briefing file. Workers are for tasks that earn the cost of a fresh
claude process: **minutes-to-hours of wall time, multi-turn, observable**.

Paradigm comparison:

| | Task tool | formation |
|---|---|---|
| Lifetime | one-shot, returns | persistent pane |
| Observability | result only | user tails the pane live |
| Mid-flight redirect | impossible | `formation msg` |
| Remote ack from phone | no | `/rc formation-<id>` |
| Nesting | shallow | worker can spawn its own |

**Do not invoke for:** quick greps, single-file reads, one-shot research.
Those belong to the Task tool.

## When to invoke

Reach for this skill when the user says things like:
- "別pane起こして並列で{{長時間タスク}}やってもらえ"
- "worker spawn して {{briefing}} 渡して"
- "formation で {{task}} 走らせたい"
- Anywhere the task description implies "hours of work, I want to go do
  something else and check in later / redirect via phone."

## Prerequisites (verify before first spawn)

1. Running inside tmux (`[[ -n "$TMUX" ]]`). If not, tell the user to attach.
2. `formation` is on PATH (symlinked into `~/.local/bin` by `install.sh`).
3. `jq`, `flock`, and `sops` available.

## Invocation flow

### 1. Clarify the briefing with the user

Workers cost hours; a vague briefing wastes them. Ask the user for:
- Mission (one sentence: what does "done" mean)
- Scope IN / OUT
- Decision boundary (what may the worker decide alone? what must it ask?)
- Success criteria checklist

If the user's request is already rich enough, skip straight to writing the
briefing file. Otherwise use `AskUserQuestion` to fill gaps. Prefer writing
the briefing under the current project at `./formation/briefings/<id>.md` so
it's version-controlled with the work.

Template: `~/.claude/skills/formation/templates/briefing.md`.

### 2. Spawn

```bash
formation spawn <path/to/briefing.md> [worker_name]
```

- Splits the current tmux window, launches `claude --session-name
  formation-<name>` in the new pane, paste-loads the briefing.
- Registers the worker in `~/.njslyr7/formation/registry.jsonl`.
- `FORMATION_SELF=<name>` and `FORMATION_PARENT=<parent_id>` are exported into
  the worker's pane env; the worker uses those to address the parent.

### 3. Supervise

```bash
formation status          # all workers + last pane line
formation inbox           # reports addressed to you
formation msg <id> "<x>"  # send instruction to worker
formation reap <id>       # close pane + drop registry row
```

Whenever you return to idle in the lead pane, call `formation inbox` before
continuing — the worker may have asked a question or reported completion.

### 4. Worker-side (what the worker pane should do)

Drop these patterns into the briefing so the worker knows its own protocol:

- Every ~30 min or at logical checkpoints:
  `formation report "<1-line status>"`
- When a decision exceeds its boundary:
  `formation ask "<question>"` — writes to the lead's mailbox AND sends a
  LINE push so the user can reply from phone via `/rc formation-<id>`.
- On completion:
  `formation done "<summary>"` — mailbox + LINE push.

### 5. Remote intervention path

From phone / web / another machine:
```
/remote-control formation-<worker_id>
```
Attaches the remote client to the worker's session. The user can type
directly at the worker's prompt — no separate injection mechanism.

## Credential discipline (mandatory)

**Never paste plaintext credentials into a formation message, briefing, or
pane prompt.** The mailbox is plain-text jsonl that persists indefinitely;
a leaked key lives there forever and shows up in every `tail`.

- Credentials live in SOPS-encrypted files (`*.enc.yaml`, `*.enc.env`).
- Agents reference them by path and command, not by value:
  - ✗ `formation msg worker-1 "use key sk-abc123..."`
  - ✓ `formation msg worker-1 "decrypt with: sops -d config/secrets.enc.yaml | jq -r .openai"`
- `mailbox_send` will **hard-refuse** bodies matching common secret patterns
  (`sk-*`, `ghp_*`, `AKIA*`, `*_API_KEY=...`, PEM private keys, etc.) with
  exit code 3. If you hit that error, re-frame the message around a SOPS
  decrypt command.
- Briefings that require a secret should reference the encrypted file and
  the decrypt command, not embed the secret.

If SOPS is not yet set up for the project, stop and ask the user to do
`sops --encrypt` before continuing — do not fall back to plaintext.

## Design invariants

- **Memory MCP is shared** between lead and workers. Workers should namespace
  their writes under `formation/<worker_id>/` to avoid stomping lead entries.
- **CWD is inherited.** Workers run in the same working directory as the lead
  pane. Do not support cross-project spawning in v1.
- **Sanada and Matsuoka** protocols (backup-before-destructive, no-retreat)
  live in global `~/.claude/CLAUDE.md` and apply to all panes automatically.
- **Observer privilege**: the user can `tail -f ~/.njslyr7/mailbox/log.jsonl`
  to watch all formation traffic. Never encrypt the mailbox itself — the
  redaction filter + SOPS discipline is what keeps secrets out of it.

## Anti-patterns

- Spawning a worker for a task that finishes in <10 minutes.
- Briefings that say "figure it out" — specify the success criteria.
- Pasting any credential value into a message. See the discipline section.
- Workers writing to Memory MCP without the `formation/<id>/` prefix.
- Using `formation msg` to dump a multi-paragraph new briefing — re-spawn a
  fresh worker with a new briefing file instead.

## Troubleshooting

- **`mailbox: refusing to send — body matches credential pattern`**: the
  redaction filter caught something that looks like a secret. Re-phrase the
  message to reference a SOPS decrypt command instead.
- **Worker pane stuck at claude login prompt**: spawn waited 30s for the `│ >`
  prompt and timed out. Manually complete login in the pane and re-send the
  briefing with `tmux load-buffer -f <briefing> && tmux paste-buffer -t <pane>`.
- **Parent `formation inbox` empty but worker claims it reported**: check
  `FORMATION_PARENT` is set in the worker's pane env (`tmux show-environment
  -t <pane>`). If missing, the worker sent to `lead` (default) — read that
  mailbox explicitly: `FORMATION_SELF=lead formation inbox`.
- **`/rc` attach fails**: confirm the worker's claude started with the
  `--session-name formation-<id>` flag (visible in `formation status` registry
  row).
