# Formation Worker Briefing

> Replace every `{{placeholder}}` before spawning. A briefing is a contract
> between lead and worker; vagueness here surfaces as wasted hours later.

## Mission
{{one-sentence statement of what "done" looks like}}

## Scope
- IN:  {{what this worker owns}}
- OUT: {{what this worker must not touch}}

## Context
{{background the worker needs that is not in the codebase: prior decisions,
  why this task exists, constraints the lead already considered}}

## Inputs
- Working directory: {{inherited from lead pane unless overridden}}
- Key files: {{paths}}
- External resources: {{URLs, API endpoints}}
- Credentials (SOPS-only, never inline):
  - {{name}} → `sops -d {{path/to/secrets.enc.yaml}} | jq -r .{{key}}`
  - Never paste the decrypted value into a mailbox message or pane prompt.

## Expected output
- Artifacts: {{file paths the worker should create/modify}}
- Report cadence: every {{30m|1h}} via `formation report "<status>"`
- Completion: `formation done "<summary>"` when mission is met

## Decision boundary
- Worker may decide autonomously: {{list}}
- Worker MUST ask via `formation ask "<question>"` for: {{list}}

## Guardrails
- Forbidden actions: {{destructive ops outside project tree, pushes to main,
   package removal, anything in D001-D010 of CLAUDE.md}}
- Memory MCP: shared with lead. Write findings under a namespace prefix
  `formation/{{worker_id}}/` to avoid stepping on lead's entries.
- Credential discipline: SOPS-decrypt on demand, never persist decrypted
  values to disk, never include them in `formation report/ask/done` bodies.
  The mailbox will hard-refuse credential-shaped strings.

## Success criteria (checklist the worker uses to self-verify before `done`)
- [ ] {{criterion 1}}
- [ ] {{criterion 2}}
- [ ] {{criterion 3}}
- [ ] `/simplify` review passed
