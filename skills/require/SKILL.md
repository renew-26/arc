---
name: require
description: Use when you have a rough idea and want it questioned into a precise written spec before anyone builds anything.
argument-hint: "<your idea, in whatever words you have>"
---

# /arc:require

Turn a vague idea into a written requirements spec by asking you one sharp question at a
time. Each answer is scored for clarity, and the interview keeps going until the remaining
ambiguity is small enough to build against. The output is a spec file and nothing else —
this skill never writes product code.

## Use When

- You have an idea but can't yet state it in one sentence without qualifiers.
- You say "interview me", "ask me everything", "don't assume", "make sure you understand",
  "I have a vague idea", "pin down the requirements", "write me a spec".
- You already intend to build the thing, and want the requirements nailed down first.
- Past attempts ended in "that's not what I meant" and you want to prevent a repeat.
- The work is big enough that guessing wrong costs real time.

## Do Not Use When

- You're still deciding *whether* to build this, or what to build at all — use `/arc:ideate`
  for open exploration. Require assumes the intent to build already exists.
- You already have a spec or written requirements and want an execution plan — use
  `/arc:plan`.
- The request is already concrete: named files, named functions, stated acceptance
  criteria. Skip straight to `/arc:plan` or `/arc:launch`.
- You want to understand existing code rather than define new work — use `/arc:scan` or
  `/arc:trace`.
- It's a one-line fix. Just do it.

## Steps

1. **Read the room before asking anything.** If the current directory holds real source
   code that the idea touches, delegate a survey:
   `Task(subagent_type="Explore")` — ask it to map the files, patterns, and existing
   behavior relevant to the idea. Never ask the user a question the code already answers.
   Also glob `.arc/specs/*.md` and read the 1-2 most related past specs so you don't
   re-litigate settled decisions.

2. **Announce the interview.** Tell the user plainly: you'll ask one question at a time,
   show a clarity score after each answer, and stop asking once ambiguity drops below 20%.
   State the idea back in their own words and note whether you're working in an existing
   codebase or from scratch.

3. **Score the four dimensions.** After every answer, rate each from 0.0 (no idea) to 1.0
   (unambiguous), then compute ambiguity.

   | Dimension | Question it answers | Weight |
   |---|---|---|
   | Goal clarity | Can you state the objective in one sentence, no qualifiers? | 0.35 |
   | Constraint clarity | What are the boundaries, limits, and explicit non-goals? | 0.25 |
   | Success criteria | Could someone write a test that proves this works? | 0.25 |
   | Context clarity | Do we understand the surrounding system well enough to change it safely? | 0.15 |

   `ambiguity = 1 − (goal×0.35 + constraints×0.25 + criteria×0.25 + context×0.15)`

   Working from scratch with no existing system? Drop context and redistribute:
   goal 0.40, constraints 0.30, criteria 0.30.

4. **Ask one question at a time — never batch.** Pick the single lowest-scoring dimension
   and aim there. Say out loud which dimension you're targeting and why it's the current
   bottleneck. Use the interactive question tool so the user gets clickable options plus a
   free-text escape. Format the header like this:

   ```
   Round 3 | Targeting: success criteria (0.4) | Ambiguity: 46%
   ```

5. **Hunt assumptions, not feature lists.** A good question exposes something the user
   believes without having decided it. "When you say 'manage tasks', what does a user do
   first?" beats "what features do you want?". If a fact lives in the repo, cite it instead
   of asking: "I found JWT auth in `src/auth/` — extend that, or deliberately diverge?"

6. **Challenge the frame periodically.** Around round 4, ask what happens if a core
   assumption is inverted ("you said 10,000 users — what if it were 100? Does the design
   actually change, or is that number a guess?"). Around round 6, push for the smallest
   version that would still be worth having. Use each move once, then return to normal
   questioning.

7. **Report progress after every round.** Show the four scores, the resulting ambiguity
   percentage, what's still missing per dimension, and what the next question will target.
   Transparency is the point — the user should be able to see the gap closing.

8. **Know when to stop.** Stop and write the spec when ambiguity ≤ 20%. From round 3 on,
   honor an early exit ("enough", "just build it") — but first show which dimensions are
   still weak and warn that rework is likely. Warn softly at round 10; hard-stop at
   round 20 and write the spec with whatever clarity exists, labeled as such. If the score
   barely moves for three rounds, you're circling a symptom — ask what the thing
   fundamentally *is* rather than what it does.

9. **Write the spec** to `.arc/specs/<slug>.md`, where `<slug>` is a short kebab-case name
   from the goal. Use this structure:

   ```markdown
   # Spec: <title>

   ## Metadata
   Rounds: <n> · Final ambiguity: <n>% · Status: PASSED | EARLY_EXIT · Date: <date>

   ## Clarity Breakdown
   | Dimension | Score | Weight | Weighted |

   ## Goal
   One paragraph. No qualifiers, no "maybe".

   ## Constraints
   - Hard boundaries and limits that came out of the interview.

   ## Non-Goals
   - Things explicitly ruled out. This section is not optional.

   ## Acceptance Criteria
   - [ ] Testable, observable statements. Someone else could verify each one.

   ## Assumptions Challenged
   | Assumption | How it was questioned | What was decided |

   ## Open Questions
   - Anything still unresolved, and why it was acceptable to leave open.

   ## Interview Transcript
   <details><summary>Full Q&A</summary> Round-by-round Q, A, and score. </details>
   ```

10. **Stop.** Tell the user where the spec lives and hand off: "Spec written to
    `.arc/specs/<slug>.md`. Review it, then run `/arc:plan` to turn it into an
    implementation plan." Do not write code, do not edit source files, do not create
    branches, do not delegate implementation. Producing the spec is the whole job.

## Verification

You did this correctly when all of these hold:

- [ ] Exactly one question was asked per round — no batched questions anywhere.
- [ ] Every round named its target dimension, its score, and why it was the bottleneck.
- [ ] An ambiguity percentage was shown to the user after every single answer.
- [ ] Existing-code facts were gathered by exploring, not by asking the user.
- [ ] At least one stated assumption was explicitly challenged and its resolution recorded.
- [ ] The file `.arc/specs/<slug>.md` exists and contains goal, constraints, non-goals,
      acceptance criteria, assumptions challenged, and open questions — none empty or "TBD".
- [ ] Every acceptance criterion is something a third party could check without asking you.
- [ ] Final ambiguity is ≤ 20%, or the spec is labeled `EARLY_EXIT` with the weak
      dimensions named.
- [ ] No source file outside `.arc/specs/` was created or modified during the interview.
- [ ] The last message points at `/arc:plan` and stops there.
