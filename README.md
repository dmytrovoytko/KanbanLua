# KanbanLua

A tiny educational Kanban app in Lua for beginners.

You edit a plain list (`tasks.md`), Lua builds a markdown Kanban board (`board.md`) with tags.

No dependencies. ~200 lines of commented Lua. Good first project to learn `tables`, `io.open`, `string.match`, loops and a simple indent-stack tree.

## How it works

```sh
lua kanban.lua [tasks.md] [board.md]
```

1. You write tasks in `tasks.md`
2. Lua parses status `[ ] / [/] / [~] / [x]`, `@tags` and indent
3. Lua writes `board.md` with two views: Board + Task list

## Syntax

| You write | Means |
| --- | --- |
| `- Some idea @blog` | Backlog (no `[ ]`) |
| `- [ ] Task @lua` | Todo |
| `- [/] Task` , `- [~] Task` | Doing (same) |
| `- [x] Task` | Done |
| `  - subtask` (indented) | Child of line above, stays with parent |

- Tags: `@word` (`@lua`, `@blog`). Many per line allowed.
- Indent in: flexible — any consistent spaces, tabs = 4 spaces (`TAB_WIDTH`).
- Indent out: strict 2 spaces (`OUTPUT_INDENT`). Status uses `&nbsp;&nbsp;` (`OUTPUT_STATUS_INDENT`) because markdown collapses plain spaces in tables.
- Skipped: empty lines, `# headings`.

Config lives at the top of `kanban.lua` — one line each, no hunting.

## Example transformation

Input `tasks.md`:

```md
- Some idea @blog
  - some detail 1 @draft
- [ ] Task 1 @lua
  - [ ] subtask 1 @learning
- [/] Task 2 @coding
  - [x] subtask 2.1 @done
  - [ ] subtask 2.3 @todo
- [x] Install Lua @setup
```

Run `lua kanban.lua`, you get `board.md`:

# Kanban Board

_8 tasks: 2 Backlog | 3 Todo | 1 Doing | 2 Done_

## Board view

| Backlog | Todo | Doing | Done |
| --- | --- | --- | --- |
| Some idea `@blog`<br>&nbsp;&nbsp;↳ some detail 1 `@draft` | Task 1 `@lua`<br>&nbsp;&nbsp;↳ [ ] subtask 1 `@learning` | Task 2 `@coding`<br>&nbsp;&nbsp;↳ [x] subtask 2.1 `@done`<br>&nbsp;&nbsp;↳ [ ] subtask 2.3 `@todo` | Install Lua `@setup` |

## Task list

| Status | Task | Tags |
| --- | --- | --- |
| Backlog | Some idea | @blog |
| &nbsp;&nbsp;Backlog |   ↳ some detail 1 | @draft |
| Todo | Task 1 | @lua |
| &nbsp;&nbsp;Todo |   ↳ subtask 1 | @learning |
| Doing | Task 2 | @coding |
| &nbsp;&nbsp;Done |   ↳ subtask 2.1 | @done |
| &nbsp;&nbsp;Todo |   ↳ subtask 2.3 | @todo |
| Done | Install Lua | @setup |

Notes:
- Board groups only by top-level status. Children stay nested under the parent but keep their own `[ ]/[/]/[~]/[x]` marker.
- Task list keeps file order. Each line shows its *own* status. Subtasks get one flat indent so tops stand out.
- Counts count all lines (parents + children).

## Plain-text reading

Rendered markdown shows the indent. If you `cat` the file, `&nbsp;` looks noisy:

```sh
sed 's/&nbsp;&nbsp;/  /g' board.md | less
```

## Files

- `kanban.lua` — the app, heavily commented for learning
- `tasks.md` — you edit this
- `board.md` — generated, do not edit
- `spec.md` — full behavior spec

## Try it

1. Add `- [ ] My first task @practice` to `tasks.md`
2. Run `lua kanban.lua`
3. Open `board.md` — new card in Todo + new row in Task list
