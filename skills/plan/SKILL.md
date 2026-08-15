---
name: plan
description: Use when you want a written, reviewable implementation plan before any code is changed, or when you want an existing plan critiqued.
argument-hint: "[--consensus|--review] <what you want built or the path to a plan>"
---

# /arc:plan

## Purpose

Turn a request into a concrete implementation plan you can read, argue with, and approve
before anything is built. Plans name real files, list testable acceptance criteria, and
call out risks with mitigations. Nothing is implemented, committed, or pushed until you
say so.

## Use When

- You want to see the approach before code changes -- "plan this", "how would you do this",
  "write up a plan first"
- The work touches several areas and you want the sequence laid out
- You want a second and third opinion on a design -- "get consensus", `--consensus`
- You have a plan already and want it torn apart -- "review this plan", `--review`
- The stakes are high enough that a rewrite would hurt: auth, payments, data migrations,
  anything irreversible

## Do Not Use When

- You want the whole thing built end to end without checkpoints -- use `Skill("arc:launch")`
- You are still figuring out *what* to build, not *how* -- use `Skill("arc:ideate")` to
  explore, then `Skill("arc:require")` to pin down requirements
- You already have an approved plan and just want it executed in parallel --
  use `Skill("arc:squad")`
- Something is broken and you need the cause -- use `Skill("arc:trace")`
- The change is a one-line fix with obvious scope -- just make the change
- You asked a question that has an answer -- answer it, do not produce a document

## Steps

### Pick a mode

| Mode | Trigger | Behavior |
| --- | --- | --- |
| Direct | Default when the request is specific | Write the plan immediately |
| Consensus | `--consensus` | Planner -> architect -> critic loop until the critic approves |
| Review | `--review` | Critique an existing plan file, no new plan written |

If the request is vague -- no files, no concrete nouns, three or more areas touched --
say so and offer `Skill("arc:require")` before planning. Do not plan around a guess.

### Direct mode

1. Gather facts before writing. Spawn `Task(subagent_type="Explore")` to find the relevant
   files, existing patterns, and current behavior. Never ask the user something the
   codebase can answer.
2. Write the plan to `.arc/plans/<short-slug>.md` using the output format below.
3. Mark the plan `pending approval` and stop. Present the path and a short summary.

### Consensus mode (`--consensus`)

1. **Planner pass.** Write the initial plan plus a decision summary that MUST contain:
   - **Principles** (3-5) that constrain the design
   - **Decision drivers** (top 3) -- what actually decides this
   - **Viable options** (at least 2) with bounded pros and cons each
   - If only one option survives, an explicit **invalidation rationale** naming each
     rejected alternative and why it fails. "There was no other way" is not a rationale.
2. **Architect pass.** Spawn `Task(subagent_type="general-purpose")` briefed as a systems
   architect reviewing for structural soundness. Its output MUST include the strongest
   steelman argument *against* the favored option, at least one real tradeoff tension, and
   a synthesis path where one exists.
3. **Critic pass.** Spawn `Task(subagent_type="general-purpose")` briefed as an adversarial
   critic whose job is to reject. It MUST check that the principles and chosen option are
   consistent, that alternatives got a fair hearing, that risks name specific mitigations,
   that acceptance criteria are testable, and that verification steps are runnable. It MUST
   reject shallow alternatives, contradictory drivers, vague risks, and weak verification.

   **CRITICAL: the architect pass must fully complete before the critic pass starts. Never
   run them in parallel.** The critic reviews the architect's findings, so a parallel run
   produces two disconnected opinions instead of a review chain.
4. **Revise loop, max 5 iterations.** If the critic rejects: collect all architect and
   critic feedback, revise the plan, then return to step 2 and step 3 in that order.
   Repeat until the critic approves or 5 iterations are spent.
5. **If 5 iterations pass without approval**, present the best version with an explicit note
   that consensus was not reached and list the unresolved objections.
6. **Merge improvements.** When reviewers approve with suggestions, fold every accepted
   suggestion into the plan file before finishing, and add a short changelog at the end
   naming what changed.
7. **Write the ADR.** Consensus output MUST end with an architecture decision record:
   **Decision**, **Drivers**, **Alternatives considered**, **Why chosen**, **Consequences**,
   **Follow-ups**.
8. Mark the plan `pending approval` and stop.

### Review mode (`--review`)

1. Read the plan file from `.arc/plans/` (or the path given).
2. Spawn `Task(subagent_type="general-purpose")` briefed as an adversarial critic, using the
   same rejection criteria as consensus step 3.
3. Return one verdict: **APPROVED**, **REVISE** with specific numbered feedback, or
   **REJECT** because the approach needs replanning.

### Plan output format

Every plan contains, in order:

- **Requirements summary** -- what is being built and for whom
- **Acceptance criteria** -- concrete and testable, each one checkable by a command or a
  described observation
- **Implementation steps** -- each with the files it touches
- **Risks and mitigations** -- every risk paired with a specific mitigation
- **Verification steps** -- exact commands to run
- Consensus only: **decision summary** (principles, drivers, options) and the **ADR**

Plans save to `.arc/plans/`. Related specs live in `.arc/specs/`.

### Planning and execution are separate

Until you explicitly approve, this skill does not edit source files, run mutating shell
commands, commit, push, open pull requests, or hand off to an execution skill. It reads and
it writes plan files. That is the whole boundary.

If the user says "just do it" without naming an execution path, treat that as the end of
planning: save the plan as `pending approval` and ask which path they want. On approval,
hand off with `Skill("arc:squad")` for parallel implementation or `Skill("arc:persist")` to
drive it to done with verification.

## Verification

The plan did its job when all of these hold:

- [ ] The plan file exists under `.arc/plans/` and is marked `pending approval`
- [ ] Claims about existing code cite `file:line`; every cited path actually exists
- [ ] Acceptance criteria are testable -- a reader can say pass or fail without asking you
- [ ] No vague terms without a metric ("fast" becomes "p99 under 200ms", "reliable" becomes
      a specific failure rate)
- [ ] Every risk has a named mitigation, not a shrug
- [ ] Consensus mode: decision summary has 3-5 principles, top 3 drivers, and 2+ viable
      options -- or an explicit invalidation rationale
- [ ] Consensus mode: the ADR section is present and complete
- [ ] Consensus mode: the architect pass result was received before the critic pass started
- [ ] No source file was modified, no commit was made, no execution skill was launched
