local state = require("codetour.state")
local loader = require("codetour.loader")

local M = {}

local QF_TITLE_PREFIX = "CodeTour: "

local function basename_of(rel)
  return vim.fs.basename(rel)
end

local function step_to_qf_item(root, step)
  if step.file then
    local base = basename_of(step.file)
    return {
      filename = root .. "/" .. step.file,
      lnum = step.line or 1,
      col = 1,
      text = step.description or "",
      user_data = {
        kind = "step",
        marker = step.title or "",
        depth = step.depth or 0,
        fileline = base .. ":" .. (step.line or 1),
      },
    }
  elseif step.directory then
    local base = basename_of(step.directory)
    return {
      filename = root .. "/" .. step.directory,
      lnum = 1,
      col = 1,
      text = step.description or "",
      user_data = {
        kind = "step",
        marker = step.title or "",
        depth = step.depth or 0,
        fileline = base .. "/",
      },
    }
  elseif step.contents then
    return {
      valid = 0,
      text = step.description or step.contents or "",
      user_data = {
        kind = "step",
        marker = step.title or "",
        depth = step.depth or 0,
        fileline = "",
      },
    }
  end
  return {
    valid = 0,
    text = "(empty step)",
    user_data = { kind = "step", marker = "", depth = 0, fileline = "" },
  }
end

function M.populate_quickfix(tour)
  local root = loader.project_root_abs(tour)
  local items = {
    {
      valid = 0,
      text = tour.title,
      user_data = { kind = "header" },
    },
  }
  for _, step in ipairs(tour.steps) do
    table.insert(items, step_to_qf_item(root, step))
  end
  vim.fn.setqflist({}, " ", {
    title = QF_TITLE_PREFIX .. tour.title,
    items = items,
  })
end

local function pad_right(s, target_w)
  local w = vim.fn.strdisplaywidth(s)
  if w >= target_w then
    return s
  end
  return s .. string.rep(" ", target_w - w)
end

function M.qftf(info)
  local qf
  if info.quickfix == 1 then
    qf = vim.fn.getqflist({ id = info.id, items = 1, title = 1 })
  else
    qf = vim.fn.getloclist(info.winid, { id = info.id, items = 1, title = 1 })
  end
  if not (qf.title and qf.title:sub(1, #QF_TITLE_PREFIX) == QF_TITLE_PREFIX) then
    return nil
  end

  local items = qf.items
  local marker_w, fileline_w = 0, 0
  for _, it in ipairs(items) do
    local ud = it.user_data
    if ud and ud.kind == "step" then
      marker_w = math.max(marker_w, vim.fn.strdisplaywidth(ud.marker or ""))
      fileline_w = math.max(fileline_w, vim.fn.strdisplaywidth(ud.fileline or ""))
    end
  end
  marker_w = marker_w + 4
  fileline_w = fileline_w + 4

  local lines = {}
  for idx = info.start_idx, info.end_idx do
    local it = items[idx] or {}
    local ud = it.user_data or {}
    if ud.kind == "header" then
      table.insert(lines, it.text or ".")
    elseif ud.kind == "step" then
      local prefix = string.rep("│   ", ud.depth or 0) .. "├── "
      local desc = it.text or ""
      table.insert(lines, prefix .. pad_right(ud.marker or "", marker_w) .. pad_right(ud.fileline or "", fileline_w) .. desc)
    else
      table.insert(lines, it.text or "")
    end
  end
  return lines
end

function M.start(tour)
  state.set_active_tour(tour)
  M.populate_quickfix(tour)
  vim.cmd("botright copen")
  pcall(vim.cmd, "cfirst")
end

function M.next()
  pcall(vim.cmd, "cnext")
end

function M.prev()
  pcall(vim.cmd, "cprevious")
end

function M.goto_step(n)
  pcall(vim.cmd, "cc " .. n)
end

function M.end_tour()
  pcall(vim.cmd, "cclose")
  state.end_tour()
end

return M
