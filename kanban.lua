-- Simple ToDo Kanban -> Markdown (with nesting)
-- Usage: lua kanban.lua [tasks.md] [board.md]
-- Lesson: tables, io.open, string.match, loops, stack for tree

local input_file = arg[1] or "tasks.md"
local output_file = arg[2] or "board.md"

-- Fixed column order (Backlog + 3 classic columns)
local COLUMNS = { "Backlog", "Todo", "Doing", "Done" }

-- Config: tweak here, no hunting in code
local TAB_WIDTH = 4       -- input: 1 tab = N spaces
local OUTPUT_INDENT = "  " -- output: strict 2 spaces per level in board.md
-- Status indent for Task list. Markdown collapses plain spaces inside
-- tables, so we use "&nbsp;&nbsp;" to keep subtasks visibly indented
-- in rendered view. If you read plain .md (not rendered), replace it
-- with 2 spaces: e.g. sed 's/&nbsp;&nbsp;/  /g' board.md
local OUTPUT_STATUS_INDENT = "&nbsp;&nbsp;"

-- Trim spaces from both ends. Lesson: string.match with captures.
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Expand tabs to spaces using TAB_WIDTH constant
local function expand_tabs(s)
  return s:gsub("\t", string.rep(" ", TAB_WIDTH))
end

-- Escape | so it doesn't break markdown tables
local function escape_cell(s)
  return (s:gsub("|", "\\|"))
end

-- Count leading spaces before '-' (call AFTER expand_tabs).
-- Returns nil if line has no dash bullet.
local function get_indent_n(line)
  local spaces = line:match("^(%s*)%-")
  if not spaces then return nil end
  return #spaces
end

-- Prefix for board.md table cells: <br> + &nbsp; per level.
-- Uses #OUTPUT_INDENT so strict 2-space rule scales to HTML.
-- Level 1 -> "", level 2 -> "&nbsp;&nbsp;", level 3 -> x2, ...
local function cell_indent_prefix(level)
  if level <= 1 then return "" end
  local units = #OUTPUT_INDENT * (level - 1)
  return string.rep("&nbsp;", units)
end

-- Prefix for flat Task list: single OUTPUT_INDENT for any subtask.
-- Level 1 -> "", level >= 2 -> OUTPUT_INDENT + arrow (flat, easy top scan).
local function list_indent_prefix(level)
  if level <= 1 then return "" end
  return OUTPUT_INDENT .. "↳ "
end

-- Prefix for Status column: same flat rule, HTML indent (no arrow).
-- Level 1 -> "", level >= 2 -> single OUTPUT_STATUS_INDENT, so tops stand out.
-- NOTE: plain spaces get collapsed by markdown renderers inside tables,
-- that's why we use &nbsp; here (see OUTPUT_STATUS_INDENT comment above).
local function status_prefix(level)
  if level <= 1 then return "" end
  return OUTPUT_STATUS_INDENT
end

-- Parse one line -> task table or nil (skip empty / headings)
-- Rules (see spec.md):
--   "- text"         => Backlog, marker ""
--   "- [ ] text"     => Todo,    marker "[ ]"
--   "- [/] or [~]"   => Doing,   marker preserved "[/]" / "[~]"
--   "- [x]/[X]"      => Done,    marker "[x]"
local function parse_line(raw_line)
  local line = expand_tabs(raw_line)
  if trim(line) == "" then return nil end
  if trim(line):sub(1, 1) == "#" then return nil end -- skip # headings

  local indent_n = get_indent_n(line)
  if not indent_n then return nil end -- not a "- ..." line

  local text, status, marker

  if line:match("^%s*%-%s*%[%s%]") then
    status, marker = "Todo", "[ ]"
    text = line:match("^%s*%-%s*%[%s%]%s*(.+)$") or ""
  elseif line:match("^%s*%-%s*%[/%]") then
    status, marker = "Doing", "[/]"
    text = line:match("^%s*%-%s*%[/%]%s*(.+)$") or ""
  elseif line:match("^%s*%-%s*%[~%]") then
    status, marker = "Doing", "[~]"
    text = line:match("^%s*%-%s*%[~%]%s*(.+)$") or ""
  elseif line:match("^%s*%-%s*%[[xX]%]") then
    status, marker = "Done", "[x]"
    text = line:match("^%s*%-%s*%[[xX]%]%s*(.+)$") or ""
  else
    -- Backlog: dash WITHOUT [ ]. Must not start with [
    local rest = line:match("^%s*%-%s*(.+)$")
    if rest and not rest:match("^%[") then
      status, marker = "Backlog", ""
      text = rest
    else
      return nil -- unknown [-...] marker, skip
    end
  end

  -- Lesson: gmatch loop to collect @tags
  local tags = {}
  for tag in text:gmatch("@([%w_%-]+)") do
    table.insert(tags, tag)
  end

  -- Clean task text: remove @tags for display
  local clean = trim(text:gsub("%s*@[%w_%-]+", ""))

  return { status = status, marker = marker, task = clean, tags = tags,
           indent_n = indent_n, children = {} }
end

-- Format backtick tags for board cells: ` @a` `@b`
local function cell_tag_str(tags)
  if #tags == 0 then return "" end
  return " `@" .. table.concat(tags, "` `@") .. "`"
end

-- Recursively collect child lines for a board cell.
-- Child keeps its OWN marker but stays in parent's column.
local function append_children(node, parts)
  for _, child in ipairs(node.children) do
    local line = cell_indent_prefix(child.level) .. "↳ "
    if child.marker ~= "" then line = line .. child.marker .. " " end
    line = line .. escape_cell(child.task) .. cell_tag_str(child.tags)
    table.insert(parts, line)
    append_children(child, parts) -- deeper levels
  end
end

local function render_cell(top)
  local head = escape_cell(top.task) .. cell_tag_str(top.tags)
  if #top.children == 0 then return head end
  local parts = {}
  append_children(top, parts)
  return head .. "<br>" .. table.concat(parts, "<br>")
end

-- 1. READ + BUILD TREE. Lesson: stack handles any consistent indent.
local all_tasks = {} -- flat, file order (parents + children)
local tops = {}      -- level-1 nodes only, file order
local board = { Backlog = {}, Todo = {}, Doing = {}, Done = {} }

local f = io.open(input_file, "r")
if not f then
  print("Cannot open " .. input_file .. ". Create it first!")
  os.exit(1)
end

local stack = {}        -- ancestor nodes
local indent_stack = {} -- their indent_N values

for raw in f:lines() do
  local t = parse_line(raw)
  if t then
    -- Pop until we find a parent with smaller indent
    while #stack > 0 and indent_stack[#stack] >= t.indent_n do
      table.remove(stack)
      table.remove(indent_stack)
    end
    t.level = #stack + 1
    table.insert(all_tasks, t)
    if #stack == 0 then
      table.insert(tops, t)
      table.insert(board[t.status], t) -- group ONLY by top-level status
    else
      table.insert(stack[#stack].children, t)
    end
    table.insert(stack, t)
    table.insert(indent_stack, t.indent_n)
  end
end
f:close()

-- Counts by OWN status (sums to total)
local count = { Backlog = 0, Todo = 0, Doing = 0, Done = 0 }
for _, t in ipairs(all_tasks) do
  count[t.status] = count[t.status] + 1
end

-- 2. WRITE board.md
local out = io.open(output_file, "w")

out:write("# Kanban Board\n\n")
out:write(string.format(
  "_%d tasks: %d Backlog | %d Todo | %d Doing | %d Done_\n\n",
  #all_tasks, count.Backlog, count.Todo, count.Doing, count.Done))

-- View 1: 4-column Kanban (tops only, children nested inside)
out:write("## Board view\n\n")
out:write("| Backlog | Todo | Doing | Done |\n")
out:write("| --- | --- | --- | --- |\n")

local max_rows = math.max(#board.Backlog, #board.Todo, #board.Doing, #board.Done, 1)
for i = 1, max_rows do
  local cells = {}
  for _, col in ipairs(COLUMNS) do
    local top = board[col][i]
    table.insert(cells, top and render_cell(top) or "")
  end
  out:write("| " .. table.concat(cells, " | ") .. " |\n")
end

-- View 2: flat list in file order, strict OUTPUT_INDENT
out:write("\n## Task list\n\n")
out:write("| Status | Task | Tags |\n")
out:write("| --- | --- | --- |\n")
for _, t in ipairs(all_tasks) do
  local tag_str = ""
  if #t.tags > 0 then tag_str = "@" .. table.concat(t.tags, ", @") end
  local shown = list_indent_prefix(t.level) .. escape_cell(t.task)
  local shown_status = status_prefix(t.level) .. t.status
  out:write(string.format("| %s | %s | %s |\n",
    shown_status, shown, escape_cell(tag_str)))
end

out:close()

print(string.format("Done! %d tasks (%d top-level) -> %s",
  #all_tasks, #tops, output_file))
