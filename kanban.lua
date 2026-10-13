-- Simple ToDo Kanban -> Markdown
-- Usage: lua kanban.lua [tasks.md] [board.md]
-- Lesson: tables, io.open, string.match, loops

local input_file = arg[1] or "tasks.md"
local output_file = arg[2] or "board.md"

-- Fixed column order (Backlog + 3 classic columns)
local COLUMNS = { "Backlog", "Todo", "Doing", "Done" }

-- Trim spaces from both ends. Lesson: string.match with captures.
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Escape | so it doesn't break markdown tables
local function escape_cell(s)
  return (s:gsub("|", "\\|"))
end

-- Parse one line -> task table or nil (skip empty / headings)
-- Rules you chose:
--   "- text"         => Backlog
--   "- [ ] text"     => Todo
--   "- [/] text"     => Doing
--   "- [x] text"     => Done
local function parse_line(line)
  if trim(line) == "" then return nil end
  if trim(line):sub(1, 1) == "#" then return nil end -- skip # headings

  local text, status

  if line:match("^%s*%-%s*%[%s%]") then
    status = "Todo"
    text = line:match("^%s*%-%s*%[%s%]%s*(.+)$") or ""
  elseif line:match("^%s*%-%s*%[/%]") then
    status = "Doing"
    text = line:match("^%s*%-%s*%[/%]%s*(.+)$") or ""
  elseif line:match("^%s*%-%s*%[[xX]%]") then
    status = "Done"
    text = line:match("^%s*%-%s*%[[xX]%]%s*(.+)$") or ""
  else
    -- Backlog: dash WITHOUT [ ]. Must not start with [
    local rest = line:match("^%s*%-%s*(.+)$")
    if rest and not rest:match("^%[") then
      status = "Backlog"
      text = rest
    else
      return nil -- unknown format, skip
    end
  end

  -- Lesson: gmatch loop to collect @tags
  local tags = {}
  for tag in text:gmatch("@([%w_%-]+)") do
    table.insert(tags, tag)
  end

  -- Clean task text: remove @tags for the Kanban cells
  local clean = trim(text:gsub("%s*@[%w_%-]+", ""))

  return { status = status, task = clean, tags = tags }
end

-- 1. READ file into a list of tasks. Lesson: io.open + tables.
local tasks = {}
local f = io.open(input_file, "r")
if not f then
  print("Cannot open " .. input_file .. ". Create it first!")
  os.exit(1)
end
for line in f:lines() do
  local t = parse_line(line)
  if t then table.insert(tasks, t) end
end
f:close()

-- 2. GROUP by status
local board = { Backlog = {}, Todo = {}, Doing = {}, Done = {} }
for _, t in ipairs(tasks) do
  table.insert(board[t.status], t)
end

-- 3. WRITE board.md. Lesson: io.open "w" + string concatenation.
local out = io.open(output_file, "w")

out:write("# Kanban Board\n\n")
out:write(string.format(
  "_%d tasks: %d Backlog | %d Todo | %d Doing | %d Done_\n\n",
  #tasks, #board.Backlog, #board.Todo, #board.Doing, #board.Done))

-- View 1: 4-column Kanban
out:write("## Board view\n\n")
out:write("| Backlog | Todo | Doing | Done |\n")
out:write("| --- | --- | --- | --- |\n")

local max_rows = math.max(#board.Backlog, #board.Todo, #board.Doing, #board.Done, 1)
for i = 1, max_rows do
  local cells = {}
  for _, col in ipairs(COLUMNS) do
    local t = board[col][i]
    if t then
      local tag_str = ""
      if #t.tags > 0 then tag_str = " <br>`@" .. table.concat(t.tags, "` `@") .. "`" end
      table.insert(cells, escape_cell(t.task) .. tag_str)
    else
      table.insert(cells, "")
    end
  end
  out:write("| " .. table.concat(cells, " | ") .. " |\n")
end

-- View 2: flat table with tags
out:write("\n## Task list\n\n")
out:write("| Status | Task | Tags |\n")
out:write("| --- | --- | --- |\n")
for _, t in ipairs(tasks) do
  local tag_str = ""
  if #t.tags > 0 then tag_str = "@" .. table.concat(t.tags, ", @") end
  out:write(string.format("| %s | %s | %s |\n",
    t.status, escape_cell(t.task), escape_cell(tag_str)))
end

out:close()

print(string.format("Done! %d tasks -> %s", #tasks, output_file))
