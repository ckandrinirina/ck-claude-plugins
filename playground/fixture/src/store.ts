import { readFileSync, writeFileSync, existsSync } from "node:fs";

export interface Todo {
  id: number;
  title: string;
  done: boolean;
}

export function load(path: string): Todo[] {
  if (!existsSync(path)) return [];
  return JSON.parse(readFileSync(path, "utf8")) as Todo[];
}

export function save(path: string, todos: Todo[]): void {
  writeFileSync(path, JSON.stringify(todos, null, 2) + "\n");
}

export function add(todos: Todo[], title: string): Todo[] {
  const trimmed = title.trim();
  if (!trimmed) throw new Error("title must not be empty");
  const id = todos.reduce((max, t) => Math.max(max, t.id), 0) + 1;
  return [...todos, { id, title: trimmed, done: false }];
}

export function complete(todos: Todo[], id: number): Todo[] {
  if (!todos.some((t) => t.id === id)) throw new Error(`no todo with id ${id}`);
  return todos.map((t) => (t.id === id ? { ...t, done: true } : t));
}
