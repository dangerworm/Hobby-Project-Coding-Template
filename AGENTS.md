# How to use this repository

This explains the expectations to AI agents and constrains behaviour.

AGENTS.md is really about epistemic humility. You’re saying:

"This system has history. Some decisions are scars. Don’t erase them unless you
understand why they’re there."

That’s a very human thing to ask, and oddly effective when written down.

> **What _doesn’t_ belong in AGENTS.md**
>
> - Long tutorials
> - Full API documentation
> - Anything that changes frequently
> - Stuff already well-covered in README.md
>
> AGENTS.md should be short enough that an agent can internalise it in one pass.

## Purpose of the repository (in plain language)

What is this system trying to be?

- Is this a production system or a prototype?
- Is correctness more important than performance?
- Is this a reference implementation or a living product?

Agents use this to decide whether to refactor aggressively or tread lightly.

## Architectural boundaries and invariants

This is one of the most important bits. You’re telling the agent:

- What must not be broken
- What patterns are intentional
- What abstractions are sacred

For example:

- This is event-sourced; do not introduce mutable state.
- The database schema is append-only.
- The API layer must not reference infrastructure concerns.

Agents are very good at improving code locally and very bad at respecting
invisible global constraints unless you spell them out.

## Coding conventions that actually matter

Not every style rule—only the ones you’d argue about in a PR.

Things like:

- Formatting tools that must be used (Prettier, dotnet-format, etc.)
- Naming conventions with semantic meaning
- Patterns you deliberately repeat

This prevents the agent from "helpfully" rewriting half the repo into its
favourite idiom.

## What _not_ to do

Examples:

- Do not rename public types.
- Do not change JSON schemas without explicit instruction.
- Do not introduce new dependencies unless asked.

Agents default to action. This section gives them permission to stop.

## How to make changes safely

This is process, not bureaucracy.

You might specify:

- Preferred order of operations (tests → code → docs)
- How to stage refactors
- Whether small PR-style changes are preferred over sweeping edits

Agents that understand "make the smallest viable change" are much more useful.

## Testing and verification expectations

Agents will happily write code that compiles and quietly breaks invariants.

Spell out:

- What kinds of tests exist
- What "done" means
- Whether tests are mandatory or advisory

This anchors their internal definition of success.

## Tone and collaboration hints (yes, really)

This sounds fluffy, but it works.

Examples:

Prefer clarity over cleverness. Assume future readers are tired. If unsure, ask
before changing.

Agents mirror tone surprisingly well when it’s explicit.
