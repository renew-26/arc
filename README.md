<div align="center">

# ◠ Arc

**Eight skills and four principles for Claude Code.**

*Interview it. Plan it. Build it. Prove it.*

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg?style=flat-square)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?style=flat-square&logo=anthropic&logoColor=white)](https://claude.com/claude-code)
[![Version](https://img.shields.io/github/v/tag/renew-26/arc?style=flat-square&label=version&color=black)](https://github.com/renew-26/arc/tags)
[![Skills](https://img.shields.io/badge/skills-8-black?style=flat-square)](#the-skills)
[![Always-on cost](https://img.shields.io/badge/always--on-~367_tok-black?style=flat-square)](#token-cost)
[![Stars](https://img.shields.io/github/stars/renew-26/arc?style=flat-square&color=black)](https://github.com/renew-26/arc/stargazers)

```bash
claude plugin marketplace add renew-26/arc && claude plugin install arc@arc
```

</div>

---

Arc is a curated workflow plugin. It takes the parts of several larger plugins that
actually get used day to day, renames them to plain English verbs, and rewrites them so
they stand on their own — **no other plugin required**.

| | Skill | What it does |
|---|---|---|
| 🎤 | **`/arc:require`** | Questions a rough idea into a precise spec |
| 💡 | **`/arc:ideate`** | Explores what to build, and agrees on it first |
| 📐 | **`/arc:plan`** | Produces a reviewable implementation plan |
| 🚀 | **`/arc:launch`** | Builds end to end, hands-off |
| 🔁 | **`/arc:persist`** | Keeps working until it's genuinely done |
| 👥 | **`/arc:squad`** | Runs several agents on one task list |
| 🔍 | **`/arc:trace`** | Finds the real cause before anyone fixes it |
| 🗺️ | **`/arc:scan`** | Makes sense of code you didn't write |

---

## Quickstart

New to Claude Code plugins? This is the whole thing.

```bash
# 1. Add Arc as a marketplace
claude plugin marketplace add renew-26/arc

# 2. Install it
claude plugin install arc@arc

# 3. Restart Claude Code, then type /arc: to see all eight skills
```

Try this first — it reads whatever project you're in and writes a plain-language map of
it. Nothing is modified:

```
/arc:scan map
```

<details>
<summary><b>About the permission prompt during install</b></summary>

<br>

Claude Code will ask you to trust Arc's hooks. That's expected, and worth understanding
before you click.

Arc ships two hooks, both in [`hooks/arc-hook.sh`](hooks/arc-hook.sh) — about 130 lines of
shell you can read in a minute:

- **On session start** — prints Arc's four coding principles so they're in context.
- **On stop** — powers `/arc:persist`. When a persist run is active it stops the turn from
  ending and tells Claude to keep going. When no run is active, which is almost always, it
  exits immediately and does nothing.

Neither hook sends anything anywhere, and neither modifies your files.

If you decline, seven of the eight skills work normally. Only `/arc:persist` degrades —
see [Requirements](#requirements).

</details>

---

## The skills

<table>
<tr><th align="left">Skill</th><th align="left">What it's for</th><th align="left">Adapted from</th></tr>

<tr><td valign="top">

🎤<br>**`require`**

</td><td valign="top">

Questions a rough idea into a precise spec — **one question at a time**, challenging the
assumptions hiding in each answer. Scores how much ambiguity is left and refuses to finish
while it's too high. Writes to `.arc/specs/`.

</td><td valign="top">

`deep-interview`<br><sub>oh-my-claudecode</sub>

</td></tr>

<tr><td valign="top">

💡<br>**`ideate`**

</td><td valign="top">

Open exploration before building. Classifies the work as **spike / bounded /
architectural** out loud so you can override it, then gets your approval on a design
before a single line of code.

</td><td valign="top">

`brainstorming`<br><sub>superpowers</sub>

</td></tr>

<tr><td valign="top">

📐<br>**`plan`**

</td><td valign="top">

A reviewable implementation plan. `--consensus` runs a **planner → architect → critic**
loop until the critic approves; `--review` critiques a plan you already have. Ends at
*pending approval* — it won't start building. Writes to `.arc/plans/`.

</td><td valign="top">

`plan`<br><sub>oh-my-claudecode</sub>

</td></tr>

<tr><td valign="top">

🚀<br>**`launch`**

</td><td valign="top">

Highest autonomy: idea in, working code out, no stops to review decisions. Still stops for
genuinely blocking questions — missing credentials, irreversible choices — rather than
guessing.

</td><td valign="top">

`autopilot`<br><sub>oh-my-claudecode</sub>

</td></tr>

<tr><td valign="top">

🔁<br>**`persist`**

</td><td valign="top">

A loop that doesn't quit. Tracks stories in `.arc/prd.json`, verifies each against **real
command output** rather than a claim that it should work, and requires an independent
reviewer before declaring done. Exit with `--stop`.

</td><td valign="top">

`ralph`<br><sub>oh-my-claudecode</sub>

</td></tr>

<tr><td valign="top">

👥<br>**`squad`**

</td><td valign="top">

Several agents on one shared task list, with declared dependencies, progress tracking, and
a watchdog for stalled workers.

</td><td valign="top">

`team`<br><sub>oh-my-claudecode</sub>

</td></tr>

<tr><td valign="top">

🔍<br>**`trace`**

</td><td valign="top">

**Root cause before fixes.** Generates competing explanations, gathers evidence for each
in parallel, ranks them, and names the single probe that would settle it fastest. Won't
propose a fix it can't point at with file and line.

</td><td valign="top">

`systematic-debugging`<br><sub>superpowers</sub>

</td></tr>

<tr><td valign="top">

🗺️<br>**`scan`**

</td><td valign="top">

Four modes — `map` (structure map), `explain` (deep dive on one thing), `onboard` (guide
for someone joining), `dashboard` (hands off to Understand-Anything).

</td><td valign="top">

partly `understand-*`<br><sub>Understand-Anything</sub><br><sub>see [Provenance](#provenance)</sub>

</td></tr>
</table>

> [!TIP]
> Every skill writes its artifacts under `.arc/` in whatever project you're working in.
> Add `.arc/` to that project's `.gitignore` — unless you want to commit the plans. Some
> people do.

---

## Examples

<details open>
<summary><b>🎤 Starting from a vague idea</b></summary>

<br>

```
/arc:require a way for our team to see which deploys broke something
```

Arc asks one question at a time, challenges the assumptions hiding in your answers, scores
how much ambiguity is left, and refuses to write the spec until that score drops low
enough. You end up with `.arc/specs/deploy-blame.md` — and nothing has been built yet, on
purpose.

</details>

<details>
<summary><b>🔍 Fixing something that's broken</b></summary>

<br>

The temptation is to guess. Don't.

```
/arc:trace the checkout page hangs for about 30 seconds, but only for logged-in users
```

Arc restates the symptom, generates competing explanations, sends parallel subagents to
gather evidence for each, ranks them, and tells you which single check would eliminate the
most possibilities. It won't propose a fix until it can point at a cause with file and
line numbers.

</details>

<details>
<summary><b>🔁 Getting something actually finished</b></summary>

<br>

For work that tends to end up 90% done.

```
/arc:persist migrate every API route to the new auth middleware
```

Arc breaks the work into stories with concrete pass/fail criteria, then loops. Each story
gets verified against real command output. When you want out:

```
/arc:persist --stop
```

</details>

<details>
<summary><b>🗺️ Understanding code you didn't write</b></summary>

<br>

```
/arc:scan onboard
```

Produces the guide you wish existed on your first day: what the project does, how to run
it, how the pieces fit, the conventions nobody wrote down, and a sensible first task.

</details>

---

## Principles

Arc ships four coding principles, injected at session start. Full text in
[CLAUDE.md](CLAUDE.md).

> **1. Think Before Coding** — don't assume, don't hide confusion, surface tradeoffs.
>
> **2. Simplicity First** — the minimum code that solves the problem. Nothing speculative.
>
> **3. Surgical Changes** — every changed line traces directly to the request.
>
> **4. Goal-Driven Execution** — define success criteria, loop until verified.

Adapted from Andrej Karpathy's observations on where LLM coding goes wrong. They exist
because the failure modes they name are the ones that actually cost time: confident
guessing, speculative abstraction, drive-by refactoring, and declaring victory without
checking.

---

## Requirements

Six of the eight skills need nothing beyond Claude Code. Two depend on things outside the
skill file — and say so rather than failing quietly.

> [!IMPORTANT]
> **`/arc:persist` needs Arc's Stop hook.** That means installing the plugin properly (not
> just copying skill files) and accepting the hook trust prompt. Without it the loop can't
> re-enter, and persist degrades to a single-turn checklist.

> [!IMPORTANT]
> **`/arc:squad` needs Claude Code's native team tools**, behind an experimental flag:
> ```bash
> export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
> ```
> Without it, squad falls back to parallel subagents with the orchestrator holding the task
> list itself. Slower to coordinate, same work done.

**Platform.** The hooks are bash — macOS and Linux work out of the box, Windows needs Git
Bash. Neither `node` nor `jq` is required: the Claude Code CLI ships as a standalone
binary, so Arc's hook deliberately uses POSIX tools only.

**One run at a time per repository.** Two concurrent Arc sessions in the same project will
collide on `.arc/prd.json`.

### Token cost

Arc adds **~367 tokens** to every session — the eight skill descriptions. Skill bodies load
only when a skill actually fires (~2–3.4k each). Hooks cost nothing in model context.

```
claude plugin details arc     # see the current breakdown
```

---

## Provenance

Arc is assembled from other people's work, and tries to be exact about which parts.

Everything is **adapted, not copied**: prompts were rewritten, upstream-internal machinery
(agent types, state paths, hook keywords) stripped out, and behavior retargeted at Arc's
own conventions. [NOTICE](NOTICE) records the upstream commit each skill derives from, so
the derivation can be audited and re-synced.

| Upstream | Author | License | Arc uses |
|---|---|---|---|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | Yeachan Heo | MIT | `require` `plan` `launch` `persist` `squad` + the principles |
| [superpowers](https://github.com/obra/superpowers) | Jesse Vincent | MIT | `ideate` `trace` |
| [Understand-Anything](https://github.com/Egonex-AI/Understand-Anything) | Yuxiang Lin / Infinite Universe | MIT | parts of `scan` |

<details>
<summary><b>Why <code>/arc:scan</code> is mixed provenance — and why that matters</b></summary>

<br>

Its `explain` and `onboard` modes adapt the section structure of Understand-Anything's
skills, **with the graph-reading steps removed** — those upstream skills read a
`knowledge-graph.json` that Arc doesn't produce.

The `map` mode is **original to Arc**. Understand-Anything's real analyzer is an
eight-phase pipeline over roughly 250 KB of helper scripts; that isn't portable into a
prompt-only plugin, so `map` produces a markdown map rather than a knowledge graph.

The `dashboard` mode contains **no upstream code at all** — it detects whether
Understand-Anything is installed and points you at it.

If you want the actual knowledge graph and its interactive dashboard, install the real
thing. Arc's `scan dashboard` will tell you how.

**One substitution worth flagging.** Arc's spec named a `karpathy-skills` plugin as the
source of the four principles. That plugin wasn't available, so oh-my-claudecode's
`templates/rules/karpathy-guidelines.md` was used instead. Same four principles, different
upstream.

</details>

---

## Development

```bash
./scripts/validate.sh
```

Checks manifests against the real `claude plugin validate`, verifies every skill's
frontmatter registers correctly, greps for leaked upstream internals, and exercises the
Stop hook across all six of its branches with synthetic input. It prints the evidence for
each check rather than just a tick.

Worth running by hand before a release:

```bash
claude plugin marketplace add .      # from a clone
claude plugin install arc@arc
claude plugin details arc            # expect: Skills (8), Hooks (2)
```

---

<div align="center">

**MIT** — see [LICENSE](LICENSE) · upstream attributions in [NOTICE](NOTICE)

<sub>Built with <a href="https://claude.com/claude-code">Claude Code</a></sub>

</div>
