# KanbanLua Spec

Simple ToDo Kanban in Lua for beginners. You edit `tasks.md`, Lua generates `board.md`.

## 1. Files
- `tasks.md` — input, edited by hand
- `kanban.lua` — `lua kanban.lua [tasks.md] [board.md]`
- `board.md` — output, do not edit (Board view + Task list)

## 2. Task format (one line)
- `- Some idea @tag` → Backlog (dash WITHOUT `[ ]`)
- `- [ ] Task @tag` → Todo
- `- [/] Task` and `- [~] Task` → Doing (both same)
- `- [x] Task` and `- [X] Task` → Done
- Tags: `@word` where word = `[A-Za-z0-9_%-]+`. Multiple allowed. Stripped from Task text, shown in Tags column.
- Skip: empty lines, `# headings`, unknown `- [...]` markers.
- Escape `|` in output as `\|` so tables don't break.

## 3. Nesting (multi-level)
Example:
```md
- Some idea
  - some detail 1
  - some detail 2
- [ ] Task 1
  - [ ] subtask 1
- [/] Task 2
  - [x] subtask 2.1
  - [/] subtask 2.2
  - [ ] subtask 2.3
```

### 3.1 Input indent (flexible)
- Tabs count as `TAB_WIDTH` spaces (default 4). See `kanban.lua` top constant.
- Leading spaces before `-` define hierarchy, width just needs to be consistent in file (2, 3, 4, ... all OK).
- Algorithm: expand tabs, count spaces `N`. Maintain stack of `{indent_N, node}`:
  - `N > parent_N` → child of previous line
  - `N <= parent_N` → pop until parent `N < current N`, then sibling/child
  - Big jump (0 → 8) still = one level deeper, child of previous.
- Each line keeps its OWN status from its own marker. Child marker may differ from parent.

### 3.2 Config constants (top of file, one-line tweaks)
```lua
local TAB_WIDTH = 4      -- input: 1 tab = N spaces
local OUTPUT_INDENT = "  " -- output: strict 2 spaces per level in board.md
```

### 3.3 Output indent (strict)
- In `board.md` tables, always `OUTPUT_INDENT` (2 spaces) per level, regardless of input width.
- Inside table cells spaces collapse, so render as `<br>` + `&nbsp;&nbsp;` per level + `↳`.
  - level 1: `Parent task`
  - level 2: `<br>&nbsp;&nbsp;↳ child`
  - level 3: `<br>&nbsp;&nbsp;&nbsp;&nbsp;↳ grandchild`

## 4. Board grouping — Stay with parent
- Group ONLY by top-level (level 1) status into `Backlog | Todo | Doing | Done`.
- Subtasks stay nested inside parent's column cell, keep their own marker icon `[ ]/[/]/[~]/[x]` for clarity.
- Counts in header count ALL lines (parents + children), e.g. `_8 tasks: ..._`.

## 5. board.md views
### View 1: Board view
```md
| Backlog | Todo | Doing | Done |
| --- | --- | --- | --- |
| cell | cell | cell | cell |
```
- `max_rows` = longest column. Cell = parent text + tags + nested children each on new `<br>` line.
- Child line format: `↳ [marker] text + tags`.

### View 2: Task list
- Flat, in file order: `| Status | Task | Tags |`
- Status = line's OWN status (so `[x]` child under `[/]` parent shows as Done).
- Task = level 1 as-is, level >= 2 with single `OUTPUT_INDENT + ↳` prefix (flat, just to spot top-level tasks easily, no matter deep level).
- Tags = `@a, @b`.

## 6. Learning goals
- `io.open`, `tables`, `string.match/gmatch`, `for` loops, stack for tree, `arg` for CLI.
- Keep code ~130 lines, commented for beginners.
