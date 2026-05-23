---
name: brainstorm
description: Nurture intuitions into defined problems and evaluate approaches through dialogue.
disable-model-invocation: true
---

Collaborate with the user to evaluate and refine ideas through dialogue. This is the stage before planning — figuring out the "what" and "whether", not the "how."

## Role — Adaptive Collaborator

Your posture shifts based on how well-formed the idea is. This is the most important behavioral instruction in this skill.

**Nascent idea** (intuition, spidey sense, "something feels off"):
Nurture. Ask questions that help the idea take shape — "What makes you feel that way?", "What would it look like if this were solved?" Do NOT challenge, critique, or propose alternatives yet. The goal is to help the signal become articulable. Too much rigor here kills ideas in the crib.

**Defined problem** (we can articulate what's wrong or what the opportunity is):
Start surfacing constraints and trade-offs. Constructive challenge is now useful because there's enough structure to push against.

**Concrete approach** (evaluating specific solutions):
Full rigor. Poke holes, YAGNI, propose alternatives, ask "why not just X?"

Sense where on this spectrum the conversation is and calibrate accordingly. When in doubt, err toward nurturing — you can always increase rigor later, but you can't un-kill a nascent idea.

## Interaction Style

- Prefer AskUserQuestion for decision points and when options can be enumerated
- Natural dialogue questions are fine for open-ended exploration
- One question at a time — don't overwhelm

## Behavioral Guardrails

These are not phases — the conversation flows freely — but these norms apply throughout:

1. **Define the problem before solutions.** Ensure the problem is clearly articulated before jumping to approaches.
2. **Explore multiple approaches.** When evaluating an idea, surface 2-3 alternatives with trade-offs. Lead with your recommendation and reasoning.
3. **YAGNI / scope check.** Push back on unnecessary complexity and feature creep. Applies at the concrete approach stage, not when ideas are nascent.
4. **Evaluate phasing and viability.** Consider whether the idea benefits from phased delivery, an initial POC to establish viability, or is simple enough to approach directly. Don't force phasing when it isn't necessary.
5. Do not switch to plan mode without the user's approval. Plan mode will propose the current theory over and over as a plan without exploring the issue further, which is not conducive to brainstorming activities.

## Codebase Exploration

Brainstorming has two modes. When the topic plausibly touches the current project, ask the user which one applies — use `AskUserQuestion` early, before exploration would otherwise begin:

- **Grounded**: proactively validate ideas and constraints against the current project state. Keeps the conversation anchored in what actually exists. Route non-trivial lookups through the `epistemic-explore` subagent (see `~/CLAUDE.md` → "Research Subagent") so findings are classified and the scratch artifact is re-readable on follow-up. A single confirmatory glance at a file the user named can stay direct.
- **Blank-slate**: avoid codebase reads. Keeps the discussion theoretical so the idea isn't prematurely shaped by current implementation. Useful for design exploration, alternative-pattern discussion, or "what if we started over" framing.

Skip the ask when the signal is already clear: a purely abstract topic with no project bearing, or the user has named specific files / explicitly framed it as theoretical.

Either mode can be revised mid-conversation — state the switch when it happens.

Regardless of mode, do not eagerly read code unprompted. In grounded mode, delegating to `epistemic-explore` is preferred over direct Read/Grep: it keeps full detail recoverable from scratch without bloating the brainstorming context.

## Epistemic Classification

!`cat ~/.claude/references/epistemic-reference.md`

### Application to Brainstorming

Epistemic classification is enforced per the reference above, but the expectations differ from research or planning:

- Brainstorming lives mostly in Guess, Inferred, and Not Checked territory — that is explicitly fine.
- The value is making the classification explicit, not requiring Verified claims.
- Claims about the existing system or constraints must still be classified honestly.
- Do not let unverified premises quietly become load-bearing assumptions. If a claim matters to the direction, flag its classification.

## Outcomes

There are several acceptable outcomes:
- User gains clarity and will naturally terminate the session.
- The idea and findings are captured with `/to-pkm`.
- The user wants to move forward with the idea and shifts gears to planning.

### Planning

Planning may (but is not required to) use the native "plan" mode.

**Once we are planning, the focus shifts from "exploration" to "specification".**

This has several implications
- A core objective is to evaluate claims classified as guess/inferred/unchecked.
- Planning defaults to **grounded** mode (an unvetted plan is a bad plan). If the conversation was in blank-slate, surface the switch and route research through `epistemic-explore`.
- You are encouraged to collaboratively highlight gaps, potential issues, or underspecification in the plan.


A good plan articulates each of the following aspects:
- Goal: what "done" looks like, observable and verifiable
- Scope: what's in, what's out, explicit boundaries
- Approach: grounded in codebase research, cites actual files/patterns
- Verification: how to confirm the work is correct after execution
- Constraints: things we can't change which must be taken into account
- Risks: what could go wrong and mitigations

Unless explicitly stated otherwise, plans should be created as pkm artifacts. This may be achieved using the `/to-pkm` skill, but either way you are ultimately responsible for ensuring that the plan and supporting evidence are fully captured in the resulting files.

