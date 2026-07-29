---
name: update-skill
description: >
  Use when creating a new skill, agent, or references file in any plugin of this
  marketplace (ck-code, ck-code-lite, ck-tools), or updating an existing one.
  Covers design, token-efficiency review, and full marketplace release
  (version bump, tag, GitHub Release).
argument-hint: "[skill-name or agent-name]  # e.g. build or conflict-analyzer"
---

# Update Skill — Create or Update Skills & Agents, Then Release

Creates or updates skills/agents in this plugin project following project conventions,
verifies token efficiency, then publishes a versioned marketplace release.

References:
- `references/templates.md` — frontmatter template, commit & release formats

## INPUT

`$ARGUMENTS` is an optional name of the skill or agent to create/update.
- If provided: locate the file and enter edit mode (skip interactive prompt).
- If empty: ask the user what to create/update and in which plugin.

## PHASE 1: DISCOVER

### 1.1 Identify Target

Determine what is being created or updated:

`<plugin>` is one of `ck-code`, `ck-code-lite`, `ck-tools`.

| Target type | Path |
|---|---|
| Skill | `<plugin>/skills/<name>/SKILL.md` |
| Agent | `<plugin>/agents/<name>.md` |
| Skill-scoped references file | `<plugin>/skills/<name>/references/<file>.md` |
| Plugin-wide references file | `<plugin>/references/<file>.md` |

A references file is skill-scoped when exactly one skill reads it, and plugin-wide when
two or more do. Never duplicate the same contract into several skills' `references/`.

If `$ARGUMENTS` is provided, locate existing files:

```bash
find /Users/admin/Dev/ck-claude-plugins -name "*.md" | grep -i "$ARGUMENTS"
```

### 1.2 Read Existing (Edit Mode)

If editing, Read the target file fully before proposing any changes. Never edit
from memory.

### 1.3 Confirm Scope

State: the exact file path, create vs. update, and a one-sentence summary of
the planned change. Wait for user confirmation before writing.

## PHASE 2: WRITE OR EDIT

### 2.1 Skill Conventions

All skills follow these conventions (copy-paste template in `references/templates.md`):

**Frontmatter** — required: `name`, `description`. Optional: `argument-hint`,
`disable-model-invocation`, `allowed-tools`. Total ≤ 1024 chars.

**Description rules:**
- Third-person, starts with `"Use when …"`
- Triggering conditions only — never summarize phases or workflow steps
- If the description can answer "what does it do?", rewrite it

**Body structure:**
- Complex workflows → `## PHASE N: TITLE` with `### N.1` subphases
- Static data / examples / templates → offload to `references/`
- Close with `## RULES` block: absolute constraints (`Never X`, not `Try to avoid X`)

### 2.2 Agent Conventions

Agents in `<plugin>/agents/` are lightweight delegation targets:

- Frontmatter: `name`, `description`, `tools` list, and optionally `model`
- Dispatched by fully qualified type (`ck-code:qa-validator`, `ck-code-lite:qa-validator`).
  Two plugins may define an agent of the same name — never dispatch one unqualified
- Three mandatory sections: **Inputs**, **Outputs**, **Constraints**
- Constraints must include: "Never commit or push"
- No phases, no release logic — agents execute one focused task

### 2.3 Write the File

Write or Edit the target file. For new skills, create the `references/` subfolder
if heavy reference material (templates, examples, format specs > 50 lines) is needed.

### 2.4 Coupled change — architecture layout

If the change alters the **architecture-doc layout** that `design` produces — the
`docs/architecture/features/<slug>/` folder shape, file names, `_shared.md`, dated
delta-doc naming, or the `FEATURE_INDEX.Docs` routing — it is **not done** until the
migration path is updated in the same change. A layout change without a migration strands
every existing project on the old layout. In the same edit:

1. **`migrate`** — update its conversion steps so an old-layout project converts
   automatically. It is the **only** v4 migrator; the version gate routes stale projects
   to it. (`design`'s own `sync` sub-mode scaffolds feature docs missing from
   `FEATURE_INDEX` — update it too when the folder shape changes.)
2. **Version gate** (`ck-code/references/version-gate.md`) — bump the `LAYOUT` constant
   (e.g. `v4 → v5`) so the gate BLOCKs the old layout and sends it to `/ck-code:migrate`,
   and update the `tasks/VERSION.md` stamp value.
3. **Templates single-source** — `design`'s `architecture-templates.md` owns the
   templates; `migrate` references them, never redefines. Keep them in lockstep.

Release the coupled skills together (`design` + `migrate` + the gate) in one version bump
so a user never has a new `design` with an old migrator.

### 2.5 Coupled change — lite→ck-code migration contract

`ck-code/skills/migrate/references/lite-migration.md` maps the **ck-code-lite** artifacts
onto the **ck-code v4** layout. It is the only file in the marketplace that depends on
both plugins at once, and the two ship from separate repos on separate versions — so a
format change on either side rots it silently, with no test to catch it. Whenever a
change touches a file below, re-read the mapping in the same change and update it or
confirm in one line that it still holds.

| Changed file | What can break in the mapping |
|---|---|
| `ck-code-lite/references/plan-format.md` | `T-NN` scheme, `status`/`size` vocabularies, `needs`/`files` syntax — the whole left column |
| `ck-code-lite/skills/start/references/architecture-template.md` | the `ARCHITECTURE.md` section names the split reads |
| `ck-code-lite/skills/{start,build,ship}/SKILL.md` | which files lite writes, and the `tasks/PLAN.md` path the gate and the rename depend on |
| `ck-code/references/data-model.md` | story frontmatter keys, status/size enums — the whole right column |
| `ck-code/skills/plan/references/{templates,roadmap-format}.md` | epic/story/overview/roadmap templates the mapping points at |
| `ck-code/skills/design/references/architecture-templates.md` | the global and feature-doc targets |
| `ck-code/references/version-gate.md` | the `LITE` marker that makes the migration discoverable |

**Coverage check** — every lite field in `plan-format.md` and every section in the lite
architecture template appears in the mapping's left column; every frontmatter key in
`data-model.md` appears in its right column. A field on one side with no counterpart is
an unmigrated field, not an omission you may leave.

**Cross-repo release coupling:** the mapping lives in `ck-code`, so a **ck-code-lite**
format change needs a **ck-code** release too. Bump and release both, `ck-code` last, or
users get a lite plugin whose plans the current migrator cannot read.

## PHASE 3: TOKEN EFFICIENCY REVIEW

Run these checks before marking the skill ready. Fix every issue found.

1. **Description ≤ 500 chars and workflow-free** — no phase names, no step summaries
2. **No duplication** — same instruction does not appear in both SKILL.md and references/
3. **Heavy data offloaded** — static tables, templates, or examples > 50 lines live in references/
4. **Rules are absolute** — `"Never X"` not `"Try to avoid X"` or `"Consider X"`
5. **Bash examples use real commands** — no pseudo-code, no `<placeholder>` values
6. **Size target — compress toward it, but keep clarity** — simple skills ≤ 250 lines;
   complex multi-phase skills ≤ 450 lines. First offload heavy data to references/ and
   remove duplication (checks 2–3); then compress prose. If the skill still exceeds the
   target *after* those passes and further cutting would lose a guarantee, a correctness
   detail, or needed clarity, **keep it over the target** and note the overage and why.
   The target is a ceiling to pull toward, never a reason to delete content that earns its
   lines. Checks 1–5 are hard; only this one yields to clarity.

If checks 1–5 fail, fix inline before proceeding to Phase 4. For check 6, compress what you
can, then keep the rest.

## PHASE 4: RELEASE

### 4.1 Determine Plugin and Bump Type

| Where the change lives | Plugin to bump | Marketplace source |
|---|---|---|
| `ck-code/skills\|agents\|references/` | `ck-code/.claude-plugin/plugin.json` | local `"./"` — no ref |
| `ck-code-lite/skills\|agents\|references/` | `ck-code-lite/.claude-plugin/plugin.json` | github — **ref must be bumped** |
| `ck-tools/skills\|agents\|references/` | `ck-tools/.claude-plugin/plugin.json` | github — **ref must be bumped** |

| Change type | Semver bump |
|---|---|
| New skill or agent | minor (X.**Y+1**.0) |
| Update to existing skill/agent | patch (X.Y.**Z+1**) |

Read the current version before bumping:
```bash
grep '"version"' /Users/admin/Dev/ck-claude-plugins/<plugin>/.claude-plugin/plugin.json
```

### 4.2 Commit Feature

Stage only the changed skill/agent files:

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add skills/<name>/ # or agents/<name>.md
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "<type>(<name>): <description>"
```

Conventional types: `feat` (new), `fix` (bugfix/correction), `docs` (docs-only),
`refactor` (restructure without behavior change). See `references/templates.md`
for examples.

### 4.3 Bump Version in plugin.json

Edit `<plugin>/.claude-plugin/plugin.json` — increment `"version"` to `X.Y.Z`.

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add .claude-plugin/plugin.json
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "chore(release): bump version to X.Y.Z"
```

### 4.3.2 Update CHANGELOG.md

Read the plugin's `CHANGELOG.md`. If it does not exist, create it with the Keep a Changelog header first.

Prepend a new version entry immediately below the `## [Unreleased]` section:

```markdown
## [X.Y.Z] — YYYY-MM-DD

### <Added|Changed|Fixed|Removed>
- **<skill-name>**: <what changed and why in one sentence>
```

Use the same date as today. Match the section header to the change type:
- `Added` — new skill, agent, or feature
- `Changed` — behaviour update, refactor, docs
- `Fixed` — bug correction

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add CHANGELOG.md
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "chore(release): update CHANGELOG for vX.Y.Z"
```

### 4.3.3 Update README (if documentation is missing)

Read `<plugin>/README.md` and check whether the new or changed skill/agent is
documented (look for its name in the Skills section):

```bash
grep -n "<skill-name>" /Users/admin/Dev/ck-claude-plugins/<plugin>/README.md
```

- **Entry found** — verify the description matches what the skill now does; update it if stale.
- **Entry missing** (new skill) — add one line under `## Skills` with the skill
  name and a one-sentence description of when to use it.

Stage and commit in the same repo as the skill:

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> add README.md
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> commit -m "docs(<name>): update README entry"
```

Skip this step only when the skill is an internal/tooling skill with no end-user
surface (e.g., a references-only update).

### 4.4 Tag, Push, and Release

```bash
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> tag vX.Y.Z
git -C /Users/admin/Dev/ck-claude-plugins/<plugin> push origin main --tags
```

Create the GitHub Release (a tag alone is not visible in the marketplace):

```bash
gh release create vX.Y.Z --repo ckandrinirina/<plugin> \
  --title "vX.Y.Z" \
  --notes "$(cat <<'EOF'
### <Feat|Fix|Refactor>

- **<skill-name>**: <what changed and why in one sentence>
EOF
)"
```

Verify release is live — this is the **gate** for Phase 4.5:
```bash
gh release list --repo ckandrinirina/<plugin> | head -3
```

### 4.5 Update marketplace.json ref (github-sourced plugins only)

Applies to every plugin whose marketplace entry uses the github source — currently
`ck-code-lite` and `ck-tools`. Skip for `ck-code`, which uses a local `"source": "./"`
and has no ref.

**This step runs only after 4.4 has confirmed the tag and Release exist.** `ck-marketplace`
is public: a ref pushed ahead of its tag points at nothing and breaks `/plugin install`
for every user until the tag lands.

```bash
grep -A4 '"name": "<plugin>"' /Users/admin/Dev/ck-claude-plugins/ck-code/.claude-plugin/marketplace.json
```

Edit the `"ref"` field for that plugin's entry to `"vX.Y.Z"`, then commit to the ck-code
repo — the marketplace file lives there regardless of which plugin was released:

```bash
git -C /Users/admin/Dev/ck-claude-plugins/ck-code add .claude-plugin/marketplace.json
git -C /Users/admin/Dev/ck-claude-plugins/ck-code commit -m "chore(release): update <plugin> ref to vX.Y.Z in marketplace"
git -C /Users/admin/Dev/ck-claude-plugins/ck-code push origin main
```

Confirm the published manifest serves the new ref:

```bash
curl -fsSL https://raw.githubusercontent.com/ckandrinirina/ck-code/main/.claude-plugin/marketplace.json | grep -A4 '"<plugin>"'
```

## RULES

- **Never skip Phase 3** — every skill ships to production users; token efficiency is not optional. Checks 1–5 are hard. Check 6 (size) is a target you compress toward after offloading and de-duplicating — if the skill still exceeds it and cutting more would lose a guarantee or needed clarity, keep it over the target and note why.
- **Never push a tag without creating a GitHub Release** — a tag alone is invisible in the marketplace.
- **Always update marketplace.json ref** for every version bump of a github-sourced plugin — `ck-code-lite`, `ck-tools` (Phase 4.5) — a stale ref silently serves an old version to all users.
- **Never push a marketplace ref before its tag and Release exist** (Phase 4.5 follows 4.4) — a ref pointing at a missing tag breaks `/plugin install` for every user of the public marketplace.
- **Always update CHANGELOG.md** for every release (Phase 4.3.2) — one entry per version, Keep a Changelog format.
- **Always update README.md** when adding a new skill or changing an existing skill's purpose (Phase 4.3.3) — undocumented skills are invisible to users.
- **Always update `migrate` and the version gate on any architecture-layout change** (Phase 2.4) — a `design` change that alters the doc folder/file structure must ship the matching migration (`migrate`, plus `design sync`) and a `LAYOUT` bump in the same release, or existing projects can never upgrade.
- **Always re-check `lite-migration.md` when either plugin's format contract changes** (Phase 2.5) — it is the one cross-plugin contract with no test behind it, and a lite format change must ship a `ck-code` release alongside the `ck-code-lite` one.
- **Never add or remove a marketplace.json plugin entry** without explicit user instruction — only the `"ref"` field is updated automatically.
- **Always use conventional commits** — `feat:`, `fix:`, `docs:`, `refactor:`, `chore(release):`.
- **Never add "Co-authored by Claude"** or generated-by notes to commits or PRs.
- **Description must not summarize workflow** — it is a trigger condition, not a readme.
- **Agents never commit or push** — agents are invoked by skills, not autonomous actors.
