# Update Skill — Reference Templates

## Skill Frontmatter Template

```yaml
---
name: <lowercase-slug-with-hyphens>
description: >
  Use when [specific triggering conditions — NOT workflow summary].
  [Optional: second sentence with key symptoms or contexts.]
argument-hint: "[example-arg]  # optional: describe accepted input"
disable-model-invocation: true   # only if recursive AI call risk exists
allowed-tools: "Bash(git *) Bash(gh *)"   # only if tool restriction needed
---
```

**Checklist before saving frontmatter:**
- [ ] `name` uses only letters, numbers, hyphens (no parens, dots, spaces)
- [ ] `description` starts with `"Use when …"`
- [ ] `description` contains no phase names or step summaries
- [ ] Total frontmatter ≤ 1024 characters

## Agent Frontmatter Template

```yaml
---
name: <agent-slug>
description: >
  [One sentence: what the agent does and when it is dispatched by which skill.]
tools: Read, Bash, Grep, Glob
---
```

Agent body structure:
```markdown
## Inputs
- `<param>`: description

## Outputs
- `<result>`: description (format, structure)

## Constraints
- Never commit or push
- Never modify files outside [scope]
- [additional hard constraints]
```

## Conventional Commit Examples

```
feat(update-skill): add Phase 3.5 story file & code integrity verification
fix(ship): allow model to invoke ship skill from conversations
docs(parallel-build): clarify worktree isolation rules
refactor(build): consolidate TDD gate into single phase
chore(release): bump version to 1.2.6
```

## GitHub Release Notes Template

```markdown
### Feat
- **<skill-name>**: <one sentence — what changed and why>

### Fix
- **<skill-name>**: <one sentence — what was broken and how it's fixed>
```

One section per change type. Omit empty sections.

## Version Bump Decision Table

| Scenario | Old → New |
|---|---|
| New skill added | 1.2.5 → 1.3.0 |
| Existing skill updated (patch) | 1.2.5 → 1.2.6 |
| Two or more skills updated | 1.2.5 → 1.2.6 (still patch) |
| New agent added | 1.2.5 → 1.3.0 |
| References file only updated | 1.2.5 → 1.2.6 |

## Plugin Paths Quick Reference

```
ck-code:   /Users/admin/Dev/ck-claude-plugins/ck-code/
ck-tools:  /Users/admin/Dev/ck-claude-plugins/ck-tools/

plugin.json locations:
  ck-code/.claude-plugin/plugin.json
  ck-tools/.claude-plugin/plugin.json

GitHub repos:
  https://github.com/ckandrinirina/ck-code
  https://github.com/ckandrinirina/ck-tools
```
