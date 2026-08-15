---
name: persist
description: Use when a job has to actually get finished — Arc keeps working through a list of stories, checking each one, until they all pass and a reviewer signs off.
argument-hint: "[--stop] [--max=N] <what must get done>"
---

# /arc:persist

## Purpose

Turn a fuzzy "get this done" into a checklist of stories with testable acceptance criteria,
then work them one at a time until every story passes and an independent reviewer has
confirmed it. A Stop hook keeps the turn alive between iterations, so the work continues
without you having to type "keep going" each time.

## Requirements

Read this section before starting. This skill depends on machinery outside this file.

- **The Arc Stop hook must be live.** The loop only continues because
  `hooks/arc-hook.sh stop` blocks the end of each turn and re-injects a continuation
  prompt. That hook is registered by `hooks/hooks.json`, which only loads when Arc is
  installed as a plugin and the hook was trusted at install time. Copying the skill files
  into a project does **not** give you the loop.
- **Check before arming.** If the plugin is not installed, or the user declined the hook
  prompt, say so plainly and degrade: run the same PRD, the same story-by-story
  verification, and the same reviewer pass as a single-turn checklist, and tell the user
  they will need to re-prompt you to continue past a turn boundary. Never claim the loop
  is running when it isn't.
- **How to get out.** `/arc:persist --stop` sets `active=0` in the state file and ends the
  loop at the next turn boundary. Deleting `.arc/state/persist.state` does the same thing.
  Tell the user both escapes when you arm the loop — a loop nobody can stop is a bug.
- **One run per repository.** Two Arc sessions persisting in the same checkout collide on
  `.arc/prd.json`: they overwrite each other's `passes` flags and re-do finished stories.
  Before arming, check whether `.arc/state/persist.state` already exists with `active=1`.
  If it does and it belongs to a different session, stop and tell the user — do not
  overwrite it. Use separate checkouts or worktrees for parallel runs.

### The state file

`.arc/state/persist.state` is **line-oriented `key=value`, not JSON.** The hook parses it
with `grep`/`cut`, so one key per line, no quotes, no nesting, no newlines inside a value.

| Key | Value |
|---|---|
| `active` | `1` while the loop runs, `0` to stop |
| `project` | Absolute path; must equal the session's working directory or the hook ignores the file |
| `session` | Current session id; a different session will not continue your loop |
| `iteration` | Incremented by the hook on every continuation; start at `0` |
| `max_iterations` | Hard cap, default `25` |
| `goal` | One line, plain text, no line breaks |
| `msg_hash` | Written by the hook — never set this yourself |
| `updated_at` | Unix seconds (`date +%s`) |

The hook lets the turn end — quietly, with no message — when any of these is true:
`active` is not `1`; `project` does not match the session's cwd; `session` does not match;
`updated_at` is more than 6 hours old; `iteration` has reached `max_iterations`; or your
final message is byte-identical to the previous iteration's. That last one is the
no-progress guard: repeating yourself silently ends the run, so every iteration must
report something new.

## Use When

- The user says "don't stop", "keep going until it's done", "must be complete", "finish it".
- The work spans several units that each need their own verification.
- Previous attempts declared victory early and the user wants a reviewer gate this time.
- The task is well-defined enough to write acceptance criteria for right now.

## Do Not Use When

- The requirements are still vague — run `/arc:require` first, then `/arc:plan`.
- It's a one-file, one-command fix. Just do it.
- You are debugging an unknown failure — use `/arc:trace`; come back once there's a fix to
  drive to completion.
- The work is a set of independent chunks better run in parallel — use `/arc:squad`.
- The user wants to approve each step manually. A persistence loop removes those pauses.

## Steps

1. **If the argument is `--stop`, do only this:** rewrite `.arc/state/persist.state` with
   `active=0` (keep the other lines), report the final iteration count and which stories
   passed, and finish the turn. Nothing else. This is the cancel path.

2. **Confirm the hook.** Verify `hooks/hooks.json` and `hooks/arc-hook.sh` are present in
   the installed plugin. If they are not, announce the degraded single-turn mode from
   `## Requirements` and keep going — the rest of the steps still apply.

3. **Check for a live run.** Read `.arc/state/persist.state` if it exists. `active=1` with a
   different `session` means another run owns this repository: stop and report.

4. **Write the PRD** to `.arc/prd.json`. Break the goal into stories small enough to finish
   in one iteration, ordered so foundational work comes first:

   ```json
   {
     "goal": "one-line statement of done",
     "stories": [
       {
         "id": "S1",
         "title": "Reject expired tokens in the auth middleware",
         "priority": 1,
         "acceptanceCriteria": [
           "`npm test -- auth` exits 0 with the new expired-token case passing",
           "A request with an expired JWT returns 401, not 500"
         ],
         "passes": false
       }
     ]
   }
   ```

   **Acceptance criteria must name a command, a file, or an observable behavior.** Criteria
   like "implementation is complete", "code compiles", or "it works correctly" are PRD
   theater — they can be marked passed without anything being true. If you catch yourself
   writing one, replace it before moving on.

   Delegate the codebase reading this needs to `Task(subagent_type="Explore")` so the
   criteria reference real paths and real commands.

5. **Arm the loop.** Create `.arc/state/persist.state` (the directory `.arc/state/` first)
   with `active=1`, `iteration=0`, `max_iterations=25` (or `--max=N`), `project` set to the
   absolute working directory, `session` set to the current session id, `goal` on one line,
   and `updated_at` from `date +%s`. If you cannot determine the session id, leave the
   `session` line out entirely — the hook treats a missing value as unscoped. Then tell the
   user the loop is armed and how to stop it.

6. **Each iteration, pick one story.** Read `.arc/prd.json`, take the highest-priority story
   with `"passes": false`, and say which one you're on. Work one story at a time.

7. **Implement it.** Delegate the build to `Task(subagent_type="general-purpose")` briefed
   with the story, its criteria, and the relevant file paths. Run builds and test suites
   with `run_in_background: true`. If you discover work the PRD missed, add it as a new
   story rather than silently widening the current one.

8. **Verify against the criteria, not against your memory.** For each acceptance criterion,
   run the actual command and read the actual output in this iteration. Stale output from
   two iterations ago is not evidence. If any criterion fails, the story stays
   `"passes": false` — keep working it.

9. **Record and move on.** Only when every criterion of the story is confirmed, set
   `"passes": true` and append to `.arc/progress.md`: what you changed, which files, what
   the verification output said, and anything a future iteration should know. Then return
   to step 6.

10. **When every story passes, get an independent review.** Delegate to
    `Task(subagent_type="general-purpose")` briefed with a REVIEWER role: give it the full
    acceptance criteria list from `.arc/prd.json`, the list of files changed during the run,
    and instruct it to check the callers and adjacent modules — not only the edited files —
    and to answer whether a meaningfully simpler or more robust approach was missed. The
    reviewer must have done none of the implementation.

11. **On approval, run the stop path in the same turn.** Do not pause to report the approval
    and wait for acknowledgment — that is a polite stop, and the loop will just re-prompt
    you. Set `active=0` in `.arc/state/persist.state`, then summarize.

12. **On rejection, do not stop.** Flip the affected stories back to `"passes": false`, note
    the reviewer's findings in `.arc/progress.md`, and return to step 6. If the same defect
    survives three iterations, stop and report it as a likely fundamental problem rather
    than looping on it.

13. **Stop and ask when genuinely blocked** — missing credentials, an external service down,
    a requirement that turns out to be contradictory. Run the `--stop` path first so the
    user isn't fighting the loop while answering you.

## Verification

You did this correctly when all of these hold:

- [ ] `.arc/prd.json` exists and every story has criteria naming a command, file, or
      observable behavior — zero instances of "implementation is complete" or equivalent.
- [ ] Every story is `"passes": true`, and each was flipped only after fresh command output
      in that same iteration.
- [ ] `.arc/progress.md` has an entry per completed story with files changed and evidence.
- [ ] An independent reviewer that did no implementation checked the work against the
      specific acceptance criteria, and its verdict is recorded.
- [ ] No test was deleted, skipped, or weakened to make a story pass.
- [ ] `.arc/state/persist.state` ends with `active=0`, and the user was told both escape
      routes (`/arc:persist --stop` and deleting the file).
- [ ] Nothing was claimed as verified that you did not personally see output for.
