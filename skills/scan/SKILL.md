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
| `dashboard` | A self-contained HTML page rendering the map, written to `.arc/dashboard.html` |

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
8. **Write two files** into `$SCAN_ROOT/.arc/` (`mkdir -p` first). Overwrite either if it
   exists -- both are regenerable artifacts, not documents to merge -- but say that you
   replaced them.

   **`map.md`** -- one section per item above, for a human to read. Every claim carries a
   `file:line` or file path. State what you did not examine.

   **`map.json`** -- the same findings as data, so `dashboard` can render them. Emit exactly
   this shape; omit a field you could not determine rather than guessing a value:

   ```json
   {
     "project":   { "name": "", "root": "", "description": "",
                    "languages": [], "fileCount": 0, "lineCount": 0,
                    "generatedAt": "YYYY-MM-DD", "commit": "" },
     "modules":   [ { "path": "src/api/", "role": "one sentence",
                      "files": 0, "lines": 0, "tags": [] } ],
     "entryPoints":  [ { "name": "", "path": "", "line": 0, "note": "" } ],
     "dependencies": [ { "name": "", "kind": "database|queue|api|library",
                         "evidence": "file:line where it is declared" } ],
     "risks":     [ { "path": "", "line": 0, "severity": "high|medium|low",
                      "title": "", "why": "" } ],
     "notExamined": [ "" ]
   }
   ```

   `notExamined` is not optional. An empty array is a claim of full coverage -- only use it
   if that is true.

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
2. **Read the target file** in full -- this one file is worth reading completely.
3. **Find its neighborhood.** Grep for imports the file makes, and grep the repository for
   imports *of* this file to find its callers. Note which callers are tests.
4. **Explain it** in these sections:
   - **Role** -- what this exists for, and where it sits in the architecture
   - **Internal structure** -- the functions and types it defines, and their relationships
   - **Connections** -- what it depends on, what depends on it
   - **Data flow** -- inputs, transformation, outputs, and error paths
   - **Notes** -- patterns, idioms, gotchas, and anything surprising
   Assume the reader may not know the language; explain the idioms you use.

### Mode `onboard` -- guide for someone joining

1. Read `.arc/map.md` if it exists. If it does not, run mode `map` first, then continue.
2. Read the README, contributing docs, CI workflow files, and the scripts section of the
   manifest -- these hold the run instructions and the conventions.
3. Produce the guide with these sections:
   - **What this project does** -- in plain language, no jargon in the first paragraph
   - **How to run it** -- install, build, test, run, verified against real script names
   - **Map of the codebase** -- the modules and what each owns
   - **Conventions** -- naming, layout, testing style, commit and review norms, as observed
   - **Where to be careful** -- the complex or high-stakes areas
   - **A first task** -- one concrete, small, real change a newcomer could ship
4. Offer to save it to `docs/ONBOARDING.md`. Do not write it there without being asked.

### Mode `dashboard` -- render an interactive map

Turn `.arc/map.json` into a self-contained HTML page. No graph engine, no server, no
network, no external plugin.

1. **Require the data.** If `$SCAN_ROOT/.arc/map.json` does not exist, run mode `map`
   first, then continue. Never hand-write the dashboard from memory.
2. **Read the template** at `${CLAUDE_PLUGIN_ROOT}/skills/scan/dashboard.template.html`.
3. **Substitute the payload.** The template contains the single placeholder line
   `/*__ARC_MAP_JSON__*/` inside a `<script type="application/json">` block. Replace that
   exact line with the full contents of `.arc/map.json`. Change nothing else -- the page
   renders itself from that data.
4. **Write** the result to `$SCAN_ROOT/.arc/dashboard.html`, overwriting any previous one.
5. **Tell the user how to open it**, and give the path:
   ```bash
   open .arc/dashboard.html        # macOS
   xdg-open .arc/dashboard.html    # Linux
   ```
6. **Report what the page will show them** in one or two sentences -- module count, how
   many risk hotspots, and anything the map recorded as not examined. Do not oversell a
   thin map: if the repository had little structure to find, say so.

The page is a plain file. It works offline, can be committed, attached, or opened on a
machine that has never seen Claude Code. If a publishing tool is available in the session
and the user wants a shareable link, offer it -- but the local file is always the primary
output, because it never depends on the harness.

## Verification

- [ ] The mode you ran was stated up front, including when it defaulted to `map`
- [ ] Every structural claim cites a real file path or `file:line`
- [ ] Frameworks and dependencies were read from manifests, not inferred from file names
- [ ] `map`: `.arc/map.md` exists and covers purpose, stack, entry points, modules, data
      flow, dependencies, and risk areas
- [ ] `map`: `.arc/map.json` exists, parses, and its findings match `map.md` -- the two are
      the same scan in two formats, not two different opinions
- [ ] `map` / `onboard`: the guide names what you did not examine, rather than implying
      full coverage
- [ ] `onboard`: run instructions match commands that actually exist in the repository
- [ ] `dashboard`: `.arc/dashboard.html` opens in a browser and shows the modules and risks
      from `map.json`; the only edit made to the template was the payload substitution
- [ ] No source file was modified by any mode

## Provenance

- **`map`** is original to Arc. It uses only built-in tools and has no external dependency.
- **`explain`** and **`onboard`** adapt the section structure of Understand-Anything's
  `understand-explain` and `understand-onboard` skills (MIT). Their knowledge-graph reading
  steps are removed entirely: Arc produces no graph, so these modes read the repository
  directly.
- **`dashboard`** is original to Arc. It renders `.arc/map.json` into a local HTML file and
  requires no other plugin.

No mode depends on another plugin being installed.
