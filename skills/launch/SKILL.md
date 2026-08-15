---
name: launch
description: Use when you want something built end to end from a short description, hands-off, with no stops to review decisions along the way.
argument-hint: "<what you want built, 2-3 sentences>"
---

# /arc:launch

## Purpose

Give it a short description of what you want and it runs the whole lifecycle on its own:
requirements, design, plan, implementation, QA, and verification. You describe the outcome;
it delivers working, tested code. This is the highest-autonomy skill in Arc -- it decides
and proceeds rather than checking in.

## Use When

- You want the whole thing built without managing steps -- "launch", "build me", "make me",
  "create me", "just handle it", "full auto", "I want a..."
- The work genuinely spans phases: figure out requirements, design, code, test, verify
- You trust the direction and would rather review the finished result than the decisions
- You have a green field or a well-isolated feature where a wrong turn is cheap to redo

## Do Not Use When

- **You want a say in the decisions.** Launch is the highest-autonomy path in Arc. It picks
  the architecture, the libraries, and the file layout without asking. If you want to see
  and approve the approach first, use `Skill("arc:plan")` -- that is exactly what it is for.
- You are still deciding what to build -- use `Skill("arc:ideate")`
- You want requirements written down and agreed before anything else --
  use `Skill("arc:require")`
- You already have an approved plan -- use `Skill("arc:squad")` to execute it in parallel
- Something is broken and you need the root cause -- use `Skill("arc:trace")`
- You want an audit of what already exists -- use `Skill("arc:scan")`
- It is a one-line fix or a small bug -- just fix it
- You asked "what do you suggest" or "explain" -- answer conversationally, build nothing

**Launch still stops for genuinely blocking questions.** Missing credentials, an API key it
cannot obtain, a destructive or irreversible choice (dropping a table, rewriting git history,
deleting user data, spending money), or an ambiguity where guessing wrong wastes the whole
run. In those cases it asks instead of guessing. Autonomy is about not needing hand-holding,
not about barreling through a locked door.

## Steps

Each phase completes before the next begins. Work inside a phase runs in parallel where the
pieces are independent.

1. **Phase 0 -- Requirements.** Turn the short description into a real spec.
   - If `.arc/prd.json` or a spec under `.arc/specs/` already covers this, use it and skip
     ahead to Phase 2.
   - If an approved plan already exists in `.arc/plans/`, skip Phases 0 and 1 entirely and
     start at Phase 2.
   - If the input is too vague to build from -- no concrete nouns, no observable outcome --
     run `Skill("arc:require")` to pin down requirements before continuing.
   - Otherwise spawn `Task(subagent_type="general-purpose")` briefed as a requirements
     analyst to extract functional requirements, constraints, and edge cases, then a second
     `Task(subagent_type="general-purpose")` briefed as a systems architect to turn those
     into a technical specification.
   - Output: `.arc/specs/launch-spec.md`

2. **Phase 1 -- Plan.** Turn the spec into an ordered implementation plan.
   - Run `Skill("arc:plan")` in direct mode against the spec.
   - Have a `Task(subagent_type="general-purpose")` briefed as an adversarial critic check
     the plan for untestable criteria and unmitigated risk before execution starts.
   - Output: `.arc/plans/launch-impl.md`

3. **Phase 2 -- Implementation.** Build it.
   - Run `Skill("arc:squad")` to execute independent plan steps in parallel.
   - Steps with dependencies run in order; only genuinely independent work goes wide.
   - Track completed steps in `.arc/progress.md` so an interrupted run can resume.

4. **Phase 3 -- QA.** Cycle until the build is clean.
   - Build, lint, and test. Fix what fails. Repeat, up to 5 cycles.
   - If the *same* error survives 3 cycles, stop. That is a design problem, not a typo, and
     more loops will not fix it. Report the error and what was tried.
   - When a failure's cause is not obvious, run `Skill("arc:trace")` rather than guessing at
     patches.

5. **Phase 4 -- Verification.** Review from several angles in parallel. Spawn three
   `Task(subagent_type="general-purpose")` subagents, each briefed with a different role:
   - a functional reviewer checking every acceptance criterion against real behavior
   - a security reviewer checking input handling, secrets, authz, and injection surfaces
   - a code reviewer checking quality, dead code, and consistency with the codebase
   All three must approve. Rejections get fixed and re-reviewed, up to 3 rounds.

6. **Phase 5 -- Completion.** Drive to done and close out.
   - Run `Skill("arc:persist")` to finish any remaining loose ends and confirm nothing is
     left half-built.
   - Update `.arc/progress.md` to final state.
   - Report what was built, where it lives, and how to run it.

## Verification

Launch is done when every one of these is backed by evidence, not by assertion:

- [ ] All six phases ran; none were skipped without a stated reason
- [ ] Every acceptance criterion in `.arc/specs/launch-spec.md` is met and named as met
- [ ] Tests pass -- pasted from a fresh run, not remembered from earlier
- [ ] Build succeeds -- pasted from a fresh run
- [ ] All three Phase 4 reviewers approved, with their objections either fixed or explicitly
      accepted and explained
- [ ] `.arc/progress.md` shows zero pending items
- [ ] The user got a plain summary: what was built, which files changed, how to run it
- [ ] Any question that blocked progress was asked, not guessed

If something could not be finished, say so plainly and name what is missing. A stopped run
that reports the wall it hit is worth more than a finished-looking one that skipped QA.
