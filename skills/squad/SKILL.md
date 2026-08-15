---
name: squad
description: Use when one job splits into several chunks that don't depend on each other and you want a few agents working them at once instead of one grinding through serially.
argument-hint: "[N] <task to split across agents>"
---

# /arc:squad

## Purpose

Break one task into independent, file-scoped pieces and run them concurrently: a shared
task list, one owner per task, declared dependencies, and an orchestrator that watches
progress and reassigns work when a worker stalls or fails. The point is wall-clock time —
if the pieces aren't actually independent, a squad is slower than doing it yourself.

## Requirements

Read this before you plan anything, because which path you take changes the whole shape.

**Path A — native teams.** `TeamCreate`, `SendMessage`, `TaskCreate`, `TaskList`, and
`TaskUpdate` are Claude Code's built-in team tools. They are gated behind an experimental
flag and are simply absent from your tool list when it isn't set.

- Check: run `echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-unset}"` — and confirm the tools
  actually appear to you. The env var alone is not proof; the tool list is.
- Enable: export `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in the shell before launching
  Claude Code, or add it to the `env` block of `.claude/settings.json`. Either way the
  session must be restarted — the flag is read at startup.

**Path B — fallback fan-out.** If the flag is off, do not stop and do not ask the user to go
enable it mid-task. Say one line ("native team tools are off, running as a parallel
fan-out"), then run the identical decomposition with the orchestrator holding the task list
itself:

- You keep the task list in `.arc/state/squad/tasks.json` and in your own todo list.
- Each ready task becomes a `Task(subagent_type="general-purpose")` call. Fire every
  dependency-free task **in one message** so they run concurrently.
- Workers report by returning their final message; you record it and dispatch the next wave.
- No inter-worker messaging exists on this path, so cross-worker coordination has to be
  designed out during decomposition rather than negotiated at runtime.

Everything below applies to both paths. Where a native tool is named, the fallback
equivalent is you doing it by hand.

**Squad state** lives under `.arc/state/squad/`:

- `events.jsonl` — one JSON object per line, appended, never rewritten: `{"ts":...,
  "event":"task_started|task_completed|task_failed|reassigned","task":"3","worker":"w2",
  "note":"..."}`. This is the audit trail when something goes sideways.
- `workers/<name>.json` — per worker: assigned task ids, current task, last update time,
  failure count. Update it when a worker's status changes; it is what tells you a worker
  has gone quiet.

## Use When

- The task naturally splits into 3+ pieces that touch different files or modules.
- A mechanical change has to land across many independent locations.
- The user says "in parallel", "spin up a few agents", "squad", "split this up".
- Serial execution would mean waiting through several long, unrelated build or test cycles.

## Do Not Use When

- The pieces all edit the same files — concurrent writers will clobber each other. One
  agent, sequential.
- The work is inherently sequential: each step's output is the next step's input.
- It's small enough for a single agent. Two workers on a ten-minute task is pure overhead.
- Nobody has decided what to build yet — use `/arc:require` or `/arc:plan` first.
- You need a completion guarantee with reviewer sign-off rather than throughput — use
  `/arc:persist`.

## Steps

1. **Decompose before spawning anything.** Delegate a survey to
   `Task(subagent_type="Explore")` — which files, which modules, where the shared types
   live. Then cut the work into tasks where each task:

   - owns a disjoint set of files (this is the conflict-prevention mechanism, not a nicety);
   - has a subject one line long and a description a stranger could execute;
   - carries its own verification command.

   Merge any two tasks that would edit the same file. Split any task that would take an
   agent more than roughly fifteen minutes.

2. **Declare dependencies explicitly.** Shared types, schemas, and interfaces go first and
   everything that consumes them is blocked on them. Native: `TaskCreate` for each task,
   then `TaskUpdate` with `addBlockedBy: ["1"]`. Fallback: a `blockedBy` array in
   `tasks.json`. A task is *ready* only when every id in its `blockedBy` is completed.

3. **Size the squad to the ready set, not to N.** The user's `N` is a ceiling (cap at 8).
   Spawning more workers than there are dependency-free tasks just creates idle agents.

4. **Assign owners up front — do not let workers claim.** There is no atomic claim on the
   shared list, so two workers reading it at the same moment can both take task 3. The
   orchestrator sets `owner` on every task before spawning (native: `TaskUpdate` with
   `owner`; fallback: the assignment is the prompt you send). A worker works only tasks
   already bearing its name.

5. **Spawn all workers in a single message.** This is the whole point of the skill —
   independent work is dispatched concurrently, never one-then-wait-then-next. Native:
   `Task` calls carrying `team_name` and `name`. Fallback:
   `Task(subagent_type="general-purpose")` calls, one per ready task, in one tool block.

6. **Brief each worker with the same protocol.** Include verbatim:

   ```
   You are squad worker "<name>". You execute; you do not orchestrate.

   1. Work only tasks whose owner is "<name>". Never touch another worker's task.
   2. Before starting one, mark it in_progress. Skip any task with an unfinished blockedBy.
   3. Edit only the files listed in your task. If the fix requires a file outside that list,
      STOP and report it — do not edit it. Another worker owns that file.
   4. Run your task's verification command and read the output before reporting done.
   5. Report: what changed, which files, the verification output, then mark it completed.
   6. If you cannot finish, report FAILED with the reason and leave the task in_progress.
      Do not mark failed work as completed.
   7. Never spawn subagents. Always use absolute paths.
   ```

   Native workers additionally use `TaskList`/`TaskUpdate` for status and `SendMessage` to
   the lead for reports. Fallback workers put all of that in their final message.

7. **Monitor actively.** Native: worker messages arrive as new turns on their own; poll
   `TaskList` between them for the overall picture. Fallback: each returned result is the
   status update. Either way, after every event append a line to `events.jsonl`, refresh
   `workers/<name>.json`, and check whether a completed task just unblocked something — if
   it did, dispatch the newly ready tasks immediately rather than waiting for the current
   wave to drain.

8. **Handle stalls and failures on a rule, not a feeling.**

   - A task `in_progress` with no update for ~5 minutes: ping the worker for status
     (`SendMessage`), or on the fallback path treat a non-returning agent as stuck.
   - Still nothing at ~10 minutes: consider the worker dead. Reassign its task to an idle
     worker, or respawn a fresh worker with the same brief. Log `reassigned`.
   - A worker that fails 2 tasks stops receiving new ones. Redistribute its queue.
   - A failed task that blocks others: retry it once, or drop the dependency and let the
     blocked tasks proceed degraded, or cancel the blocked branch. Pick one, log which, and
     tell the affected workers.
   - Never mark a task completed on a worker's behalf without seeing its evidence.

9. **Guard the shared edges.** If a worker reports that its task needs a file owned by
   another task, do not let it proceed. Either serialize the two tasks by adding a
   dependency, or take that edit yourself between waves. Concurrent edits to one file are
   the failure mode this whole design exists to prevent.

10. **Close the squad down.** When every real task is `completed` or terminally `failed`:
    verify the full list yourself rather than trusting the running tally, run the
    project-wide build and test suite once (workers only verified their own slice), send
    each worker a shutdown request and wait for its acknowledgment, then release the team
    with `TeamDelete`. On the fallback path there is nothing to release — the agents have
    already returned. Leave `.arc/state/squad/` in place; it is the record of what happened.

11. **Report.** One summary: what each task did, what the whole-project verification showed,
    anything that failed and why. If integration issues surfaced across worker boundaries,
    name them — they are the characteristic cost of parallel execution.

## Verification

You did this correctly when all of these hold:

- [ ] You checked whether the native team tools were actually available and said which path
      you were on before spawning anything.
- [ ] No two tasks that ran concurrently listed the same file.
- [ ] Every task had an owner assigned by you before its worker started; no worker
      self-claimed, and no task was executed twice.
- [ ] Dependencies were declared, and no blocked task started before its blocker completed.
- [ ] Every dependency-free task was dispatched in the same message as its peers — nothing
      independent ran serially.
- [ ] `.arc/state/squad/events.jsonl` has start/complete/fail lines for every task, and
      `workers/<name>.json` reflects each worker's final state.
- [ ] Any stalled or failed worker was handled by the rules in step 8, and the reassignment
      is in the event log.
- [ ] A project-wide build and test run happened after the workers finished, and you read
      its output.
- [ ] Native path only: every worker acknowledged shutdown before the team was released.
- [ ] The summary names real outcomes per task, not "all agents completed successfully".
