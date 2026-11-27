# tasks-cli

A tiny todo CLI (Node 24, TypeScript run natively, `node --test`). No dependencies.

    node src/cli.ts add buy milk
    node src/cli.ts list
    node src/cli.ts done 1
    npm test

## Feature ideas (backlog for planning tests)

- `remove <id>`: delete a todo
- `edit <id> <title>`: rename a todo
- Due dates: `add --due 2026-10-10 <title>`, and `list --overdue`
- Priorities (`--priority high|normal|low`), sorted in `list`
- `list --json` for scripting
