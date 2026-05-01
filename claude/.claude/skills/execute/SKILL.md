---
name: execute
description: >-
  Execute tk tickets with configurable supervision. Default interactive mode
  researches context, flags ambiguity, and proposes an approach for approval
  before dispatching subagents. Supervised mode dispatches directly.
argument-hint: "[task-id] [supervised]"
disable-model-invocation: true
---

Execute tk tickets collaboratively. Work is done by subagents; you approve each result before the ticket is closed.

Parse arguments:
- If `$0` equals "supervised": supervision mode = `supervised`, no task ID specified
- Otherwise: task ID = `$0` (may be empty), supervision mode = `$1`
- If supervision mode is absent or anything other than "supervised", default to `interactive`

## Supervision Modes

| Step | `interactive` (default) | `supervised` |
|---|---|---|
| Task selection | Collaborative | Collaborative |
| Pre-execution analysis | Research codebase, flag ambiguity, propose approach | Skipped |
| Approach approval | User approves before dispatch | Skipped |
| Subagent dispatch | Enriched context (ticket + approved approach) | Ticket context only |
| Result review | User approves or rejects | User approves or rejects |
| Continuation | User approves next task | User approves next task |

## Ready Tasks

!`tk ready -T planned 2>/dev/null || echo "No ready planned tasks found."`

## Execution Flow

### Task Selection

- If a task ID was parsed from arguments, use that task ID
- Otherwise, review the ready tasks above and pick the most appropriate one:
  - **Prefer `open` tasks over `in_progress` ones** — an `in_progress` task may be claimed by another session
  - Respect dependency order — earlier tasks unblock later ones
- If no tasks are ready, inform the user and stop

### Parallel Safety

Multiple `/execute` sessions can run concurrently on independent tasks:

1. **Claim verification**: Use `tk start --if=open <task_id>` as the first-line guard — it atomically claims the task only if it's still `open`, failing otherwise. If it fails, another session likely claimed it: inform the user and ask whether to proceed on that task anyway or pick a different one. The human decides — `--if=open` catches the common case, but it's not perfect (e.g., a task you yourself started earlier), so the advisory matters.
2. **Independent tasks only**: Parallel sessions should work on tasks that don't modify the same files. If two tasks touch the same files, run them sequentially to avoid git merge conflicts.
3. **Dependency awareness**: Closing a task in one session may make new tasks ready for other sessions. This is expected and safe.

### Per-Task Execution

For each task:

1. **Claim**: `tk start --if=open <task_id>`. If this fails, inform the user that the task may already be claimed by another session and ask which task to try instead.

2. **Pre-Execution Analysis** (`interactive` mode only — skip entirely in `supervised` mode):

   Before dispatching a subagent, research the ticket's context and surface anything the user should weigh in on. This catches ambiguity, missing context, and risky assumptions BEFORE a subagent spends effort on a potentially wrong approach.

   a. **Read the ticket**: `tk show <task_id>`. If the ticket has a parent, also read `tk show <parent_id>` for orchestration context. Read sibling tickets (`tk list --parent=<parent_id>`) to understand adjacent work and whether completed siblings produced output that affects this task.

   b. **Research the codebase**: Spawn an `epistemic-explore` subagent to investigate the ticket's implementation surface:
      - Do the files, patterns, and APIs referenced in the ticket exist as described?
      - What is the current state of the code this ticket will modify?
      - Are there conventions, existing implementations, or utilities the ticket should leverage?
      - Are there risks the ticket didn't account for (breaking changes, complex dependencies, test gaps)?
      - Does the ticket's scope overlap with any in-progress work? (Check `tk list --status=in_progress`)

   c. **Synthesize and present findings** to the user, organized as:

      - **Questions**: Ambiguities or underspecified behavior that need human clarification before work begins. For each question, propose a concrete resolution — the user can accept, modify, or provide a different answer. If there are no genuine ambiguities, omit this section rather than manufacturing questions.
      - **Risks**: Potential issues the subagent might encounter — breaking changes, missing test coverage, file contention with in-progress tickets, assumptions that don't match the codebase. For each risk, propose a mitigation. Omit if none found.
      - **Proposed approach**: Concrete implementation plan — key files to modify, pattern to follow, test strategy, commit scope. This is what the subagent will be told to do.

      The goal is to minimize the user's verification burden: present synthesized findings with proposed resolutions, not raw agent output. The user should be able to approve most items without doing their own analysis.

   d. **Iterate**: Use `AskUserQuestion` to get the user's input. They may:
      - Approve the approach as-is
      - Answer questions and accept/modify risk mitigations
      - Redirect the approach entirely
      - Decide the ticket needs amendment before execution (update the ticket via `tk edit`, then re-analyze)

      Continue the dialogue until the user explicitly approves the approach. Do not rush past this phase — it is where the most value is.

   e. **Persist the approved approach** on the ticket so it survives session boundaries:
      ```bash
      tk add-note <task_id> "Approved approach: <brief summary of agreed approach, key decisions, and resolved questions>"
      ```

3. **Execute**: Dispatch a subagent (using the Agent tool) to implement the task. The subagent prompt must include:
   - The full output of `tk show <task_id>`
   - The contents of the core execution reference: read `~/.claude/references/core-execute.md` and include it
   - If the ticket has a parent, include `tk show <parent_id>` for orchestration context
   - **(`interactive` mode)**: The approved approach from pre-execution analysis — framed as the agreed implementation plan, not merely a suggestion. The subagent should follow this approach unless it discovers something that makes it impossible, in which case it should report back rather than improvise.
   - Instruction to commit work but NOT to call `tk close` (the human gates that)

4. **Present Results**: When the subagent returns, present to the user:
   - Summary of what was done
   - Files modified
   - Verification results (tests, linting, etc.)
   - Any concerns or follow-up tickets created
   - The diff of changes (use `git diff` or `git diff --cached` as appropriate)
   - **(`interactive` mode)**: Whether the subagent followed the approved approach or deviated, and why

5. **Human Gate**: Ask the user to approve or reject the work:
   - **Approved**: `tk close <task_id>`. Then **clean the workspace**: run `git status`, stage and commit all relevant changes (implementation files, ticket status files — skip transient editor state like workspace.json, settings.local.json), and verify the workspace is clean before proceeding. Then **re-run `tk ready -T planned`** (the earlier list may be stale — other sessions, ralph, or manual changes can alter state) and present the fresh list. Ask the user whether to continue. The user may simply approve continuing (you pick the best candidate) or specify a task ID. **Do not start the next task without explicit approval.**
   - **Rejected with rationale**: Incorporate the feedback and dispatch another subagent attempt. Do not re-run `tk start` (task is already in_progress).

### Continuation

Never autonomously pick up a new task. After each completed task, you **must** get explicit user approval before proceeding. The user may:
- Approve continuing (you select the best candidate from the fresh ready list)
- Approve continuing and specify a task ID
- Decline or stop

The loop stops when:
- The user declines to continue
- No more ready tasks remain
- The user explicitly stops

After stopping, show a summary: which tasks were completed, which are still in progress, what `tk ready -T planned` returns now.
