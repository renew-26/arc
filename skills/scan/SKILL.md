---
name: scan
description: Use when you want to understand an unfamiliar codebase — a map of the whole project, a deep dive on one file, or an onboarding guide for someone new.
argument-hint: "[map|explain|onboard|dashboard] [file path, for explain]"
---

# /arc:scan

## Purpose

Read a codebase and explain it back in plain language. Four modes, one entry point:

| Mode | What you get |
|------|--------------|
| `map` (default) | A structure map of the whole repository, written to `.arc/map.md` |
| `explain` | A deep dive on one file, function, or module |
| `onboard` | A guide for someone joining the project |
| `dashboard` | Pointer to the Understand-Anything plugin, which renders graphs |

If no mode is given, run `map`. If the argument is a path rather than a mode name, run
`explain` on that path.

**Resolve the target before anything else.** Every mode below operates on a *scan root*:
the path given as an argument, otherwise the current working directory. Establish it once
and state it out loud, because it is not always the repository root:

```bash
SCAN_ROOT="${1:-$PWD}"
git -C "$SCAN_ROOT" rev-parse --show-toplevel 2>/dev/null   # empty = not a git repo
```

If the scan root is a subdirectory of a larger repository (a package, a plugin directory, a
monorepo member), say so, and scope your reading to the scan root — but read framing files
like the README from wherever they actually live, noting when they describe the parent
rather than your target. Output always goes to `$SCAN_ROOT/.arc/`, created with
`mkdir -p "$SCAN_ROOT/.arc"`.

## Use When

- You just cloned a repository and have no idea what any of it does
- You need to know which module owns a behavior before changing it
- Someone is joining the project and needs a written starting point
- You are about to plan work and want the lay of the land first

## Do Not Use When

- You know where the code is and just want to read it -- open the file
- Something is broken and you want the cause -- use `/arc:trace`
- You want a design or an implementation plan -- use `/arc:ideate` or `/arc:plan`
- You want the code changed -- scanning writes documentation, never source

## Steps

### Mode `map` (default) -- survey the repository

Uses only built-in tools: Glob, Grep, Read, and `git`. No external dependency, no plugin.

1. **Frame the repository.** `git log --oneline -20`, the README, and the top-level file
   listing. Note the project's own description of itself and whether it matches the code.
2. **Detect languages and frameworks from evidence.** Manifests (`package.json`,
   `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`), lockfiles, config files. Record the
   file that proves each finding -- never assert a framework you did not see declared.
3. **Find the entry points.** Binaries and `main`, server bootstraps, CLI definitions,
   route registrations, exported package roots, scheduled jobs. Grep for the manifest's
   declared entry fields rather than guessing filenames.
4. **Identify the main modules.** Use directory structure as the first cut, then correct it
   by reading. For each module, state what it is responsible for in one sentence.
5. **Trace data flow between modules.** Follow imports outward from the entry points. Where
   does a request or a job enter, what transforms it, where does it land.
6. **List external dependencies and integration points.** Databases, queues, third-party
   APIs, environment variables, secrets. Grep for client construction and env reads.
7. **Mark the risky parts.** Longest files (`wc -l`), anything touching auth, money,
   migrations, or concurrency, and — where history is available — the code with the most
   churn. Churn needs real history, so check first:
   ```bash
   git -C "$SCAN_ROOT" rev-list --count HEAD 2>/dev/null
   git -C "$SCAN_ROOT" rev-parse --is-shallow-repository 2>/dev/null
   ```
   A shallow clone, a fresh repository, or a non-git directory has no churn signal. Say so
   in the output rather than silently dropping the criterion or inventing a ranking.
8. **Write `$SCAN_ROOT/.arc/map.md`** (`mkdir -p` first) with one section per item above.
   Overwrite any existing map — it is a regenerable artifact, not a document to merge —
   but mention that you replaced it. Every claim carries a `file:line` or file path. State
   what you did not examine.

**Read selectively.** Sample representative files -- the largest module, one typical
handler, one typical test -- and grep for patterns across the rest. Never dump the whole
tree into context. For a large repository, dispatch several
`Task(subagent_type="Explore")` subagents in one message, one per top-level area, and
assemble their reports. **Spot-check what they hand back** — a `file:line` you inherited
from a subagent is a claim, not a fact. Open a sample of the cited lines and confirm they
say what the report says before the citation reaches your output.

### Mode `explain` -- deep dive on one component

Target comes from the argument: a file path, or `path/to/file.ts:functionName`.

1. **Locate the target.** Glob for the path; grep for the symbol if only a name was given.
   If it is ambiguous, list the candidates and ask which one.
2. **Check for optional enrichment** (see *Optional enrichment* below). Use it if present;
   proceed normally if not.
3. **Read the target file** in full -- this one file is worth reading completely.
4. **Find its neighborhood.** Grep for imports the file makes, and grep the repository for
   imports *of* this file to find its callers. Note which callers are tests.
5. **Explain it** in these sections:
   - **Role** -- what this exists for, and where it sits in the architecture
   - **Internal structure** -- the functions and types it defines, and their relationships
   - **Connections** -- what it depends on, what depends on it
   - **Data flow** -- inputs, transformation, outputs, and error paths
   - **Notes** -- patterns, idioms, gotchas, and anything surprising
   Assume the reader may not know the language; explain the idioms you use.

### Mode `onboard` -- guide for someone joining

1. Read `.arc/map.md` if it exists. If it does not, run mode `map` first, then continue.
2. Check for optional enrichment (below).
3. Read the README, contributing docs, CI workflow files, and the scripts section of the
   manifest -- these hold the run instructions and the conventions.
4. Produce the guide with these sections:
   - **What this project does** -- in plain language, no jargon in the first paragraph
   - **How to run it** -- install, build, test, run, verified against real script names
   - **Map of the codebase** -- the modules and what each owns
   - **Conventions** -- naming, layout, testing style, commit and review norms, as observed
   - **Where to be careful** -- the complex or high-stakes areas
   - **A first task** -- one concrete, small, real change a newcomer could ship
5. Offer to save it to `docs/ONBOARDING.md`. Do not write it there without being asked.

### Mode `dashboard` -- defer to Understand-Anything

Arc does not build a knowledge graph, so it cannot render one. Do not attempt to.

Resolve the data directory and test for a graph in one command — each Bash call is a fresh
shell, so compute `UA_DIR` inline rather than relying on a variable set earlier:

```bash
UA_DIR=$([ -d "$SCAN_ROOT/.understand-anything" ] && echo .understand-anything || echo .ua); \
  ls "$SCAN_ROOT/$UA_DIR/knowledge-graph.json" 2>/dev/null
ls -d ~/.claude/plugins/cache/*/understand-anything/*/ 2>/dev/null   # is the plugin installed?
```

- **Understand-Anything installed and `$UA_DIR/knowledge-graph.json` exists** → tell the user
  to run `/understand-anything:understand-dashboard`. Do not launch it yourself, and do not
  invoke it through the Skill tool -- that errors when the plugin is installed but disabled.
- **Installed, but no graph file** → tell them to run `/understand-anything:understand` first
  to build the graph, then the dashboard command.
- **Not installed** → say so plainly. Name it: plugin `understand-anything`, marketplace
  `Egonex-AI/Understand-Anything`. Offer `/arc:scan map` as the built-in alternative --
  markdown rather than an interactive graph, but no install required.

### Optional enrichment (`explain` and `onboard`)

These modes work directly from the repository. If an Understand-Anything graph happens to be
present, use it as a supplement -- never as a requirement.

Check for a graph in one self-contained command — **each Bash call is a fresh shell, so
`UA_DIR` never survives between calls; recompute it inline every time:**

```bash
UA_DIR=$([ -d "$SCAN_ROOT/.understand-anything" ] && echo .understand-anything || echo .ua); \
  ls "$SCAN_ROOT/$UA_DIR/knowledge-graph.json" 2>/dev/null
```

If that prints a path, grep the file for the names you care about and fold any summaries
into your own reading. If it prints nothing, say nothing about it and carry on from source.

**Read efficiently, always.** Grep before you read. Never dump a whole graph file, or a
whole large source file, into context. Read the sections you need.

## Verification

- [ ] The mode you ran was stated up front, including when it defaulted to `map`
- [ ] Every structural claim cites a real file path or `file:line`
- [ ] Frameworks and dependencies were read from manifests, not inferred from file names
- [ ] `map`: `.arc/map.md` exists and covers purpose, stack, entry points, modules, data
      flow, dependencies, and risk areas
- [ ] `map` / `onboard`: the guide names what you did not examine, rather than implying
      full coverage
- [ ] `onboard`: run instructions match commands that actually exist in the repository
- [ ] `dashboard`: you gave the correct branch for the situation and did not try to render
      anything yourself
- [ ] No source file was modified by any mode

## Provenance

- **`map`** is original to Arc. It uses only built-in tools and has no external dependency.
- **`explain`** and **`onboard`** adapt the section structure of Understand-Anything's
  `understand-explain` and `understand-onboard` skills (MIT). Their knowledge-graph reading
  steps are removed: Arc does not produce a graph, so these modes work from the repository
  and treat a graph as optional enrichment.
- **`dashboard`** defers entirely to Understand-Anything. Arc implements no part of it.
