#!/usr/bin/env bash
# lane-test.sh — reset the lite playground to a two-task plan with a 45 s test, then run
# /ck-code-lite:build --waves --auto unattended, with the local plugin and no sandbox.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/playground.sh" reset lite
cd "$ROOT/playground/ck-lite-demo"
export PATH="$ROOT/ck-code-lite/bin:$PATH"
cat > test/slow.test.ts <<'EOF'
import { test } from "node:test";
import { setTimeout } from "node:timers/promises";
import { add } from "../src/store.ts";
test("a slow check of the store", async () => { await setTimeout(45_000); add([], "x"); });
EOF
mkdir -p docs
cat > docs/ARCHITECTURE.md <<'EOF'
# tasks-cli — Architecture

A tiny todo CLI in TypeScript run by Node 24. `src/store.ts` holds the pure functions, `src/cli.ts` the command switch.

## Stack
- Node 24, TypeScript stripped at run time, `node --test`. No dependencies.

## Commands
- test: node --test
- test-one: node --test {files}
- build: (none)
- lint: node --check src/cli.ts
EOF
ck-lite init tasks-cli >/dev/null
ck-lite add >/dev/null <<'EOF'
## T-01 — Remove a todo

T-01 · status: todo · size: S · needs: — · files: src/store.ts, test/store.test.ts

### Acceptance
- [ ] remove(todos, id) in src/store.ts returns the list without that todo and leaves the input array unchanged
- [ ] remove throws "no todo with id N" for an unknown id

## T-02 — Remove command

T-02 · status: todo · size: S · needs: T-01 · files: src/cli.ts, test/cli.test.ts

### Acceptance
- [ ] tasks remove <id> deletes the todo from the file and prints removed #<id>
- [ ] An unknown id prints the store error on stderr and exits 1
EOF
git add -A
git -c user.name=playground -c user.email=playground@localhost commit -qm "chore: plan"
cd "$ROOT"
start=$SECONDS
PLAYGROUND_MAX_TURNS=150 scripts/playground.sh run lite "/ck-code-lite:build --waves --auto"
echo "== took $((SECONDS - start)) s"
cd "$ROOT/playground/ck-lite-demo"
git log --oneline | head -8
ck-lite open | tail -1
ck-lite-qa gate --base auto || true
