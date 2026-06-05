---
name: closeout
description: >-
  End-of-session handoff — captures session state, suggests /to-pkm for durable
  context, writes ephemeral handoff file, and adds breadcrumbs to in-progress tickets.
disable-model-invocation: true
---

Prepare an end-of-session handoff that preserves context a cold-starting agent cannot reconstruct from git or code alone.

The handoff file is ephemeral — overwritten on each closeout. Anything worth preserving beyond one session boundary should be captured durably (via `/to-pkm` or memory) before writing the handoff.

## Phase 1: Gather State

Run these in parallel:

- `git rev-parse --abbrev-ref HEAD` — current branch
- `git log --oneline -5` — recent commits
- `git status --short` — working tree state
- `tk list --status=in_progress 2>/dev/null` — in-progress tickets (may be empty)

Derive the handoff file path. The project key matches the directory where your memory system lives:

```bash
PROJECT_KEY=$(pwd | tr '/' '-')
HANDOFF_DIR="$HOME/.claude/projects/$PROJECT_KEY"
HANDOFF_PATH="$HANDOFF_DIR/handoff.md"
```

If `$HANDOFF_DIR` does not exist, create it with `mkdir -p`.

## Phase 2: Suggest Durable Capture

Before writing the ephemeral handoff, review the conversation for context that is valuable beyond the next session:

- User feedback that shaped approach decisions
- Design decisions with rationale
- Constraints or preferences the user expressed
- Research findings or rejected approaches with reasons

If any of this exists, suggest `/to-pkm` to capture it durably. Present what you'd recommend capturing and why it's worth more than an ephemeral handoff.

Use `AskUserQuestion` — the user may:
- Approve and run `/to-pkm` (do that first, then continue to Phase 3)
- Decline (continue to Phase 3)
- Identify specific items to capture

Do not skip this phase. The handoff gets overwritten — anything durable buried in it is a loss.

If nothing in the conversation warrants durable capture, say so and move on. Do not manufacture suggestions.

## Phase 3: Write Handoff

Synthesize the handoff following this schema. Target 20–40 lines. Optimize for what a cold-starting agent CANNOT reconstruct from git/code.

```
## Session
- Date: <today>
- Branch: <branch>
- Last commit: <hash> <message>
- Working tree: <clean/dirty — if dirty, list modified files>

## Active Work
<ticket IDs with one-line status each — NOT a restatement of the ticket>
<omit section if no tickets are in progress>

## Next Steps
<ordered list — specific enough that no exploration is needed>

## Context
<things only known from this conversation — omit if nothing qualifies>
- <user feedback that shaped decisions>
- <approaches tried and rejected, with why>
- <constraints or preferences expressed this session>

## Files
<files actively being modified, one-line note on what's happening in each>
<omit section if working tree is clean and no files were being iterated on>
```

**Do NOT include:**
- Summary of what was accomplished (redundant with git log)
- Verification commands (belong in tickets or codebase)
- Full decision rationale (if durable, should have been captured via /to-pkm in Phase 2)

Write the handoff to `$HANDOFF_PATH` using the Write tool.

## Phase 4: Ticket Breadcrumbs

For each in-progress ticket found in Phase 1:

```bash
tk add-note <task_id> "Session ended <date>. Handoff context at $HANDOFF_PATH"
```

Skip this phase if no tickets are in progress.

## Phase 5: Report

Briefly confirm:
- Handoff file location and that it was written
- Which tickets were annotated (if any)
- Any /to-pkm artifacts created in Phase 2 (if any)

Then output a copy-pasteable **bootstrap prompt** for the next session as the final thing in your message. The user will paste this verbatim as the first message in a fresh session — it must be self-contained and not depend on this conversation's context.

Requirements for the bootstrap prompt:
- Wrap it in a fenced code block so it's easy to copy.
- First line: point the new agent to the absolute handoff file path (the resolved `$HANDOFF_PATH`, not the literal variable).
- Second line: state the top next step from the handoff's Next Steps #1, in one sentence, specific enough that the new agent can act on it without exploration.
- Keep it to 2–4 lines total. No preamble, no headers, no markdown formatting inside the block beyond plain prose.
- **Tone: warm but calm, not command-heavy.** The bootstrap prompt sets the tone for the entire next session. Write it like you're handing off to a colleague.

Example shape (do not copy verbatim — derive from the actual handoff):

```
There's a handoff from last session at /Users/me/.claude/projects/-Users-me-Code-foo/handoff.md — can you take a look? Then we can pick up with <specific next action from Next Steps #1>.
```

The session is ready to end.
