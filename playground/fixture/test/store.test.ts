import { test } from "node:test";
import assert from "node:assert/strict";
import { add, complete } from "../src/store.ts";

test("add assigns increasing ids and trims the title", () => {
  const todos = add(add([], " buy milk "), "call bob");
  assert.deepEqual(todos.map((t) => [t.id, t.title]), [[1, "buy milk"], [2, "call bob"]]);
});

test("add rejects an empty title", () => {
  assert.throws(() => add([], "   "), /must not be empty/);
});

test("complete marks only the matching todo", () => {
  const todos = complete(add(add([], "a"), "b"), 2);
  assert.deepEqual(todos.map((t) => t.done), [false, true]);
});

test("complete rejects an unknown id", () => {
  assert.throws(() => complete([], 9), /no todo with id 9/);
});
