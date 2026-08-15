# Arc

Eight skills and four principles for Claude Code.

Arc is a curated workflow plugin. It pulls the parts of several larger plugins that
actually get used day to day, renames them to plain English verbs, and rewrites them so
they work on their own — no other plugin required.

```
/arc:require   turn a rough idea into a precise written spec
/arc:ideate    explore what to build, and get agreement before building it
/arc:plan      produce a reviewable implementation plan
/arc:launch    build something end to end, hands-off
/arc:persist   keep working until every story passes and a reviewer signs off
/arc:squad     run several coordinated agents against one task list
/arc:trace     find the real cause of a bug before anyone fixes it
/arc:scan      understand a codebase you didn't write
```

---

## Quickstart

New to Claude Code plugins? This is the whole thing.

**1. Add Arc as a marketplace.**

```bash
claude plugin marketplace add renew-26/arc
```

**2. Install it.**

```bash
claude plugin install arc@arc
```

**3. Restart Claude Code.** Then type `/arc:` and you'll see the eight skills.

Try this first:

```
/arc:scan map
```

It reads the project you're in and writes a plain-language map of it to `.arc/map.md` —
what the project is, how it's put together, and where the complicated parts are. Nothing
is modified.

### About the permission prompt

During install, Claude Code will ask you to trust Arc's hooks. This is expected and worth
understanding before you click.

Arc ships two hooks, both in `hooks/arc-hook.sh` (about 130 lines of shell — read it):

- **On session start**, it prints Arc's four coding principles so they're in context.
- **On stop**, it powers `/arc:persist`. When a persist run is active, it stops the turn
  from ending and tells Claude to keep going. When no run is active — which is almost
  always — it exits immediately and does nothing.

Neither hook sends anything anywhere, and neither modifies your files. If you decline the
prompt, seven of the eight skills still work normally; only `/arc:persist` degrades (see
[Requirements](#requirements)).

---

## The skills

| Skill | What it's for | Adapted from |
|---|---|---|
| `/arc:require` | Questions a rough idea into a precise spec, one question at a time, and refuses to finish while too much is still ambiguous. Writes to `.arc/specs/`. | oh-my-claudecode `deep-interview` |
| `/arc:ideate` | Open exploration before building. Classifies the work as spike / bounded / architectural, then gets your approval on a design. | superpowers `brainstorming` |
| `/arc:plan` | A reviewable implementation plan. `--consensus` runs a planner → architect → critic loop; `--review` critiques a plan you already have. Writes to `.arc/plans/`. | oh-my-claudecode `plan` |
| `/arc:launch` | Highest autonomy: idea in, working code out, no stops along the way. | oh-my-claudecode `autopilot` |
| `/arc:persist` | A loop that doesn't quit. Tracks stories in `.arc/prd.json`, verifies each against real command output, and requires an independent reviewer before declaring done. | oh-my-claudecode `ralph` |
| `/arc:squad` | Several agents on one shared task list, with dependencies and progress tracking. | oh-my-claudecode `team` |
| `/arc:trace` | Root cause before fixes. Generates competing explanations, gathers evidence for each, and names the probe that would settle it fastest. | superpowers `systematic-debugging` |
| `/arc:scan` | Four modes: `map` (structure map), `explain` (deep dive on one thing), `onboard` (guide for someone joining), `dashboard` (hands off to Understand-Anything). | partly Understand-Anything — see [Provenance](#provenance) |

Every skill writes its artifacts under `.arc/` in whatever project you're working in.
**Add `.arc/` to that project's `.gitignore`**, unless you want to commit the plans — some
people do.

---

## Examples

**Starting from a vague idea.** You know roughly what you want but not the details.

```
/arc:require a way for our team to see which deploys broke something
```

Arc asks one question at a time, challenges the assumptions hiding in your answer, scores
how much ambiguity is left, and refuses to write the spec until that score is low enough.
You end up with `.arc/specs/deploy-blame.md` — and nothing has been built yet, on purpose.

**Fixing something that's broken.** The temptation is to guess. Don't.

```
/arc:trace the checkout page hangs for about 30 seconds, but only for logged-in users
```

Arc restates the symptom, generates several competing explanations, sends parallel
subagents to gather evidence for each, ranks them, and tells you which single check would
eliminate the most possibilities. It won't propose a fix until it can point at a cause
with file and line numbers.

**Getting something actually finished.** For work that tends to end up 90% done.

```
/arc:persist migrate every API route to the new auth middleware
```

Arc breaks the work into stories with concrete pass/fail criteria, then loops. Each story
gets verified against real command output — not a claim that it should work. When you want
out:

```
/arc:persist --stop
```

**Understanding code you didn't write.**

```
/arc:scan onboard
```

Produces the guide you wish existed on your first day: what the project does, how to run
it, how the pieces fit, the conventions nobody wrote down, and a sensible first task.

---

## Principles

Arc ships four coding principles, injected at session start. Full text in
[CLAUDE.md](CLAUDE.md).

1. **Think Before Coding** — don't assume, don't hide confusion, surface tradeoffs.
2. **Simplicity First** — the minimum code that solves the problem. Nothing speculative.
3. **Surgical Changes** — every changed line traces directly to the request.
4. **Goal-Driven Execution** — define success criteria, loop until verified.

These are adapted from Andrej Karpathy's observations on where LLM coding goes wrong. They
exist because the failure modes they name are the ones that actually cost time: confident
guessing, speculative abstraction, drive-by refactoring, and declaring victory without
checking.

---

## Requirements

Six of the eight skills need nothing beyond Claude Code. Two depend on things outside the
skill file, and say so rather than failing quietly.

**`/arc:persist` needs Arc's Stop hook.** That means installing the plugin properly (not
just copying the skill files) and accepting the hook trust prompt. Without the hook the
loop can't re-enter, and persist degrades to a single-turn checklist — still useful, but
it won't keep going on its own.

**`/arc:squad` needs Claude Code's native team tools**, which are behind an experimental
flag:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Without it, squad falls back to dispatching parallel subagents with the orchestrator
holding the task list itself. Slower to coordinate, same work done.

**Platform.** The hooks are bash. macOS and Linux work out of the box; Windows needs Git
Bash. Neither `node` nor `jq` is required — the Claude Code CLI ships as a standalone
binary, so Arc's hook deliberately uses POSIX tools only.

**One run at a time per repository.** Two concurrent Arc sessions in the same project will
collide on `.arc/prd.json`.

---

## Provenance

Arc is assembled from other people's work, and tries to be exact about which parts.

Everything is adapted, not copied: prompts were rewritten, upstream-internal machinery
(agent types, state paths, hook keywords) was stripped out, and behavior was retargeted at
Arc's own conventions. [NOTICE](NOTICE) records the upstream commit each skill derives
from, so the derivation can be audited and re-synced.

Three upstreams, all MIT:

- **[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** by Yeachan Heo —
  `require`, `plan`, `launch`, `persist`, `squad`, and the four principles.
- **[superpowers](https://github.com/obra/superpowers)** by Jesse Vincent — `ideate` and
  `trace`.
- **[Understand-Anything](https://github.com/Egonex-AI/Understand-Anything)** by Yuxiang
  Lin / Infinite Universe, Inc. — parts of `scan`.

**`/arc:scan` is mixed, and the mix matters.** Its `explain` and `onboard` modes adapt the
section structure of Understand-Anything's skills, with the graph-reading steps removed —
those upstream skills read a `knowledge-graph.json` that Arc doesn't produce. The `map`
mode is **original to Arc**: Understand-Anything's real analyzer is an eight-phase pipeline
over roughly 250 KB of helper scripts, which isn't portable into a prompt-only plugin, so
`map` produces a markdown map rather than a knowledge graph. The `dashboard` mode contains
no upstream code at all — it detects whether Understand-Anything is installed and points
you at it.

If you want the actual knowledge graph and its interactive dashboard, install the real
thing; Arc's `scan dashboard` will tell you how.

**One substitution worth flagging.** Arc's specification named a `karpathy-skills` plugin
as the source of the four principles. That plugin wasn't available, so
oh-my-claudecode's `templates/rules/karpathy-guidelines.md` was used instead. Same four
principles, different upstream.

---

## Development

```bash
./scripts/validate.sh
```

Checks manifests against the real `claude plugin validate`, verifies every skill's
frontmatter registers correctly, greps for leaked upstream internals, and exercises the
Stop hook across all six of its branches with synthetic input. It prints the evidence for
each check rather than just a tick.

Not covered there, and worth running by hand before a release:

```bash
claude plugin marketplace add .          # from a clone
claude plugin install arc@arc
claude plugin details arc                # expect: Skills (8), Hooks (2)
```

## License

MIT — see [LICENSE](LICENSE). Upstream attributions in [NOTICE](NOTICE).
