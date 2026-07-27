# CK Claude Plugins

> Open-source plugins for [Claude Code](https://www.anthropic.com/claude-code) that keep AI-assisted software engineering grounded in your real design.

**📖 Documentation:** **https://ckandrinirina.github.io/ck-claude-plugins/**

This repository hosts **`ck-marketplace`**, the Claude Code marketplace for three plugins:

| Plugin | What it does | Docs |
|---|---|---|
| **[ck-code](https://ckandrinirina.github.io/ck-claude-plugins/ck-code.html)** | Spec-driven workflow: design → plan → team → build → ship. Architecture docs, epics & stories, per-project expert skills, TDD with SOLID checks, parallel worktree builds and GitHub Issues integration. | [ck-code repo](https://github.com/ckandrinirina/ck-code) |
| **[ck-code-lite](https://ckandrinirina.github.io/ck-claude-plugins/ck-code-lite.html)** | The same workflow trimmed to three skills and two files: `start` (architecture + flat plan), `build` (failing test first, isolated QA, manual sign-off), `ship` (commit + PR). No epics, no generators. | [ck-code-lite repo](https://github.com/ckandrinirina/ck-code-lite) |
| **[ck-tools](https://ckandrinirina.github.io/ck-claude-plugins/ck-tools.html)** | Utility toolkit: `deliver` (commit + PR), `implement` (on-the-go stories), `dependency-upgrade`, `gh-issue`, `release-prep`, `showcase`, `bmad-guide` (orientation for BMAD Method projects). | [ck-tools repo](https://github.com/ckandrinirina/ck-tools) |

`ck-code` delivers features; `ck-tools` handles the surrounding work. They're built to coexist without overlapping.

**`ck-code` or `ck-code-lite`?** They are alternatives, not companions — enable one per project. Start with `ck-code-lite` to get an app working; move to `ck-code` when the task list outgrows a single file or more than one person is planning the work.

## Install

```bash
# From inside Claude Code — add the marketplace once
/plugin marketplace add ckandrinirina/ck-code

# Install whichever plugins you want
/plugin install ck-code@ck-marketplace
/plugin install ck-code-lite@ck-marketplace
/plugin install ck-tools@ck-marketplace
```

Restart your Claude Code session, then enable a plugin per project in its `.claude/settings.json`:

```json
{ "enabledPlugins": { "ck-code@ck-marketplace": true } }
```

See the **[documentation site](https://ckandrinirina.github.io/ck-claude-plugins/)** for the full workflow, command reference, examples and changelog.

## The documentation site

The site under [`site/`](./site) is a static, no-framework page deployed to GitHub Pages by [`.github/workflows/deploy-pages.yml`](./.github/workflows/deploy-pages.yml). The changelog page is sourced live from each plugin's own `CHANGELOG.md`, so it stays the single source of truth.

## License

MIT © ckandrinirina
