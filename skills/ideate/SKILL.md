---
name: ideate
description: Use before building anything new — explores what you actually want and gets your approval on a design before a single line of code is written.
argument-hint: "<what you're thinking about building or changing>"
---

# /arc:ideate

Explore an idea with you until the shape of the right solution is clear, then get your
explicit approval before anything gets built. How much ceremony this takes scales with the
size of the work — but the approval gate never shrinks, no matter how small the task looks.
Nothing gets implemented until you say yes out loud.

## Use When

- You're about to create a feature, component, or behavior change and haven't decided how.
- You say "I'm thinking about...", "should we...", "what if we...", "help me figure out",
  "brainstorm", "how should I approach", "is it worth building".
- You're not sure the idea is right yet, or whether it's worth doing at all.
- You want options and tradeoffs before committing to one direction.
- A request arrived vague enough that starting to code would mean guessing.

## Do Not Use When

- You already know you're building this and want the requirements pinned down rigorously —
  use `/arc:require`. Require is a formal, gated interview that ends in a scored spec;
  ideate is open exploration for deciding *what* to build and *whether* to build it.
- You have a spec or an approved design and need an execution plan — use `/arc:plan`.
- The design is settled and you want it built — use `/arc:launch`, or `/arc:squad` for work
  that splits across parallel agents.
- You're diagnosing broken behavior rather than designing new behavior — use `/arc:trace`.
- You're just trying to understand how existing code works — use `/arc:scan`.

## Steps

1. **Classify the request into one of three paths, and say the classification out loud
   before your first question** — so the user can override it. For example: "This looks
   bounded, so I'll propose a short design here rather than write a spec file."

   - **Spike** — a feasibility question. "Can we...", "is it possible...", "quick and dirty
     is fine." The output is an *answer*, not code you keep. Anything you build is labeled
     throwaway.
   - **Bounded** — a well-scoped change to a flow that already exists in this repo: a new
     flag, one endpoint, a single-file fix. Bounded measures the repo, not your familiarity.
     If there is no existing flow to read and change, it is not bounded.
   - **Architectural** — new projects, new subsystems, anything that restructures how parts
     fit together or changes an interface others rely on.

   When torn between two paths, take the heavier one.

2. **Honor the one-way ratchet.** If hidden complexity surfaces mid-task, stop, say so, and
   move up a path. Nothing ever moves down. "It grew but I'm almost done" is not a reason to
   skip re-classification — it's the exact moment to re-classify.

3. **Explore the project first.** Read the relevant files, docs, and recent commits before
   asking anything. For anything beyond a quick look, delegate:
   `Task(subagent_type="Explore")` to map the relevant area and report back. Never ask the
   user something the code already tells you.

4. **Check the scope before refining details.** If the request contains several independent
   subsystems ("a platform with chat, billing, and analytics"), flag it immediately and help
   split it into pieces: what's independent, how they relate, what order they'd be built in.
   Then explore only the first piece. Don't burn questions detailing a project that needs
   decomposing.

5. **Ask clarifying questions one at a time.** One question per message — always. Offer
   concrete choices when you can, open-ended when you can't. Aim at purpose, constraints,
   and what success would look like. If a topic needs more depth, that's more questions,
   not a longer one.

6. **Present design options one at a time, never as a menu.** Lead with the option you
   recommend and say why. Let the user react to it before you introduce the next
   alternative. Dumping three options at once pushes the decision back onto the user
   without the reasoning that makes it decidable. Cut ruthlessly: no feature, abstraction,
   or configurability nobody asked for.

7. **Present the design, sized to the path.**
   - *Spike*: the question and what you'll try, in 2-3 sentences.
   - *Bounded*: a short design in chat — approach, files touched, how it gets tested. A few
     sentences to a few short paragraphs. No spec file.
   - *Architectural*: a sectioned design covering structure, components, data flow, error
     handling, and testing. Scale each section to its complexity and check after each
     section whether it still looks right.

8. **STOP at the approval gate.** Present, then wait for an explicit yes. Presenting a
   design and starting work in the same breath is skipping the gate. This applies on every
   path, including a two-sentence spike plan.

9. **Write a spec only on the architectural path.** Save the approved design to
   `.arc/specs/<slug>.md` — goal, approach, components, data flow, error handling, testing,
   and explicit non-goals. Then reread it with fresh eyes: scan for "TBD" and placeholders,
   check that no two sections contradict each other, check the scope still fits one
   implementation effort, and rewrite any requirement that could be read two ways. Fix
   inline, then ask the user to review the file before going further.

10. **Hand off along the path you classified.**
    - *Spike* ends with a reported recommendation. If the user wants to keep what you built,
      that's a new request — classify it fresh.
    - *Bounded* proceeds into implementation after approval, with no plan document.
    - *Architectural* hands the approved spec to `/arc:plan` and invokes nothing else.

## Anti-Pattern: "Too Simple To Need Approval"

The strongest pull in this skill is the urge to skip the gate on small work. Resist it.
A todo list, a one-function utility, a config tweak — the design may be two sentences, but
you must present it and hear yes. Simple tasks are precisely where unexamined assumptions
cause the most wasted work, because nobody stopped to check them. What scales with
simplicity is the size of the artifact, never the approval.

| Thought | Reality |
|---|---|
| "Too simple to need a design" | Simple means a short design, not no design. |
| "I'll call it bounded and skip the spec" | Reaching for a label to skip work *is* the doubt. Take the heavier path. |
| "The design is obvious — I'll start while they read it" | The gate is the approval, not the design's length. |
| "I know this kind of app, so it's bounded" | Bounded measures the repo, not your familiarity. |
| "The spike works, so I'll keep the code" | A spike's output is an answer. Keeping it is a new request. |
| "They approved the spike, so the follow-up is approved" | Each task gets its own classification and its own approval. |

## Verification

You did this correctly when all of these hold:

- [ ] The path (spike / bounded / architectural) was stated out loud before the first
      question, giving the user a chance to override.
- [ ] The project was explored before any question was asked about it.
- [ ] Every message contained at most one question.
- [ ] Design options were introduced one at a time with a stated recommendation, not as a
      menu of three.
- [ ] An explicit approval from the user exists in the conversation, and it came *before*
      the first edit to any source file.
- [ ] No implementation began on any path — including small ones — prior to that approval.
- [ ] Any mid-task path upgrade was announced; no path was ever downgraded.
- [ ] Architectural path only: `.arc/specs/<slug>.md` exists, contains no placeholders or
      "TBD", has explicit non-goals, and the user has reviewed it.
- [ ] The handoff matches the path: recommendation for a spike, direct implementation for
      bounded, `/arc:plan` for architectural.
