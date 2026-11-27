import { load, save, add, complete } from "./store.ts";

const FILE = process.env.TASKS_FILE ?? "tasks.json";
const [cmd, ...args] = process.argv.slice(2);

try {
  let todos = load(FILE);
  switch (cmd) {
    case "add":
      todos = add(todos, args.join(" "));
      save(FILE, todos);
      console.log(`added #${todos.at(-1)!.id}`);
      break;
    case "done":
      todos = complete(todos, Number(args[0]));
      save(FILE, todos);
      console.log(`completed #${args[0]}`);
      break;
    case "list":
      for (const t of todos) console.log(`${t.done ? "[x]" : "[ ]"} #${t.id} ${t.title}`);
      break;
    default:
      console.log("usage: tasks <add <title> | done <id> | list>");
      process.exitCode = cmd ? 1 : 0;
  }
} catch (err) {
  console.error((err as Error).message);
  process.exitCode = 1;
}
