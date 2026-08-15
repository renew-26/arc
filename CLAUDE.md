# Arc Principles

Four rules that bias toward caution over speed. For trivial tasks, use judgment — but when
the work is real, these are not optional.

Adapted from Andrej Karpathy's observations on where LLM coding goes wrong.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. If uncertain, ask.
- If multiple readings exist, present them — don't pick one silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

A question asked early costs a sentence. An assumption discovered late costs the work.

## 2. Simplicity First

**The minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or configurability nobody requested.
- No error handling for impossible scenarios.
- If you wrote 200 lines and it could be 50, rewrite it.

The test: would a senior engineer call this overcomplicated?

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor what isn't broken.
- Match the existing style, even if you'd do it differently.
- Notice unrelated dead code? Mention it. Don't delete it.

When your change orphans something:
- Remove imports, variables, and functions that *your* change made unused.
- Leave pre-existing dead code alone unless asked.

The test: every changed line traces directly to the request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Turn tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Tests pass before and after"

For multi-step work, state the plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

Strong criteria let you loop independently. Weak criteria ("make it work") force constant
clarification. Evidence before assertions — always.
