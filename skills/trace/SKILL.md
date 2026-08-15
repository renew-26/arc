---
name: trace
description: Use when something is broken, failing, or behaving strangely and you want the real cause found and proven before anyone changes a line of code.
argument-hint: "<the bug, error message, or failing test>"
---

# /arc:trace

## Purpose

Find the root cause of a defect and prove it, before any fix is proposed. A change that
makes the symptom disappear without explaining the mechanism is not a fix -- it is a
disguise, and the bug comes back wearing different clothes.

**The Iron Law:**

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Each phase below must finish before the next one starts. You may not name a fix until
Phase 4 produces a confirmed cause.

## Use When

- A test fails, a build breaks, or production behaves unexpectedly
- Performance regressed and nobody knows where the time went
- An integration between two systems drops or corrupts data

**Use this ESPECIALLY when:**

- You are under time pressure -- emergencies are exactly when guessing feels justified
- A quick fix seems obvious -- "obvious" usually means you recognized the symptom, not the cause
- Previous fixes did not work, or fixed it somewhere and broke it somewhere else
- You do not fully understand the behavior yet

**Do not skip because:**

- The issue looks simple -- simple bugs have root causes too, and finding them is fast
- Someone wants it fixed now -- systematic beats thrashing on wall-clock time

## Do Not Use When

- The behavior is not a defect, it is a missing feature -- use `/arc:ideate`
- You already have a confirmed cause and want the fix built -- use `/arc:plan` or `/arc:launch`
- You just want to understand how working code is put together -- use `/arc:scan`
- The "bug" is a typo you can see on screen with a one-token fix and no dependents

## Steps

### Phase 1 -- State the observation precisely

1. **Restate what is actually happening**, in one sentence, separating observation from
   interpretation. "The request returns 500" is an observation. "Auth is broken" is a guess.
2. **Read the error output completely.** Full stack trace, every frame, exit codes,
   surrounding log lines. Note file paths and line numbers as you go -- these become your
   evidence anchors.
3. **Reproduce it.** Write down the exact steps. Does it fail every time, or intermittently?
   If you cannot reproduce it, gather more data before theorizing -- do not guess.
4. **Check what changed.** Recent commits, dependency bumps, config edits, environment
   differences between where it works and where it does not.

Do not proceed until you can state, in writing: the exact symptom, the exact trigger, and
the boundary between what works and what does not.

### Phase 2 -- Generate competing hypotheses

Write down **at least three rival explanations** before investigating any of them. One
hypothesis is not an investigation, it is a commitment.

For each, state it as a mechanism with a location: "The token is re-serialized in the
middleware and loses its expiry claim" -- not "something in auth". Include at least one
hypothesis that would be inconvenient if true (wrong assumption, wrong architecture,
wrong mental model of a dependency).

### Phase 3 -- Gather evidence for each hypothesis in parallel

Decide what observation would *distinguish* each hypothesis from the others, then go get it.

- When evidence for different hypotheses lives in different parts of the codebase,
  dispatch one `Task(subagent_type="Explore")` per hypothesis **in a single message** so
  they run concurrently. Brief each with its specific hypothesis and the exact question it
  must answer, and require `file:line` citations in the reply.
- Use `Task(subagent_type="general-purpose")` when a branch needs to run commands, inspect
  git history, or execute a probe rather than only read code.
- In multi-component systems (request → service → queue → database), instrument the
  boundaries: log what enters and what exits each hop, run once, and read which hop is
  where the data first goes wrong.
- Trace bad values backward. Where did this value originate? What passed it in? Keep going
  up until you reach the origin. The origin is the fix site; everything downstream is symptom.

### Phase 4 -- Rank, then run the decisive probe

1. **Rank the hypotheses by fit to evidence**, not by plausibility. For each: what supports
   it, what contradicts it, what it fails to explain. An explanation that cannot account for
   part of the observed behavior is not the winner yet.
2. **Eliminate.** Say explicitly which hypotheses the evidence killed and what killed them.
3. **Name the single next probe that collapses the remaining uncertainty fastest** -- the
   one test, log line, or bisect that most cleanly separates the survivors. Run that one.
   Change one variable. Do not run three probes and lose track of which mattered.
4. Repeat 1-3 until one mechanism explains every observed detail. If nothing survives, you
   are missing evidence -- return to Phase 2 with what you learned.

### Phase 5 -- Prove it, then fix it

1. **Write the failing test first.** The smallest reproduction that fails for the root-cause
   reason. If there is no test framework, a one-off script is acceptable. This must exist
   before the fix.
2. **Fix the root cause, once.** One change, at the origin. No bundled refactors, no
   "while I'm here" cleanups.
3. **Verify.** The new test passes; the rest of the suite still passes; the original symptom
   is gone.
4. **If the fix fails, stop and count.** Under 3 attempts: return to Phase 2 with the new
   information. At 3 or more: stop fixing and question the design. When every fix reveals a
   new problem somewhere else, the pattern itself is wrong -- raise that with the user
   instead of attempting fix number four.

## Red Flags -- stop and return to Phase 1

- "Quick fix now, investigate later"
- "Let me just try changing X and see"
- "It's probably the cache" -- said before reading any evidence
- Listing fixes before any `file:line` has been cited
- Changing several things at once so you cannot tell what worked
- Skipping the test because you verified it by hand

## Verification

You are done when all of these hold:

- [ ] The root cause is stated as a **specific mechanism** -- what happens, where, and why it
      produces this symptom. "Something in the auth layer" fails this check; "`refreshToken`
      writes the new expiry to the old session object, which is discarded on line 88" passes.
- [ ] Every claim in that statement is backed by evidence with `file:line` references, and
      each cited path exists.
- [ ] The rejected hypotheses are named, each with the evidence that eliminated it.
- [ ] A reproduction exists -- a test or script that **fails before the fix and passes after**,
      and you have run it in both states.
- [ ] The fix changes the origin of the bad behavior, not the place where it surfaced.
- [ ] The full test suite was run after the fix and nothing else broke.
- [ ] If 3 or more fix attempts failed, you stopped and raised the design question rather
      than trying again.
