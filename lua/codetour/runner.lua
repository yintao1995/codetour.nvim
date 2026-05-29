local state = require("codetour.state")
local marks = require("codetour.marks")
local ui = require("codetour.ui")
local loader = require("codetour.loader")

local M = {}

local function open_file_step(tour, step)
  local root = loader.project_root_abs(tour)
  local path = root .. "/" .. step.file
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local bufnr = vim.api.nvim_get_current_buf()
  local line = step.line or 1
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  vim.cmd("normal! zz")
  marks.clear_all()
  marks.set(bufnr, line, M._progress_label())
end

local function refresh()
  local tour = state.active_tour()
  local step = state.active_step()
  if not (tour and step) then
    ui.close()
    marks.clear_all()
    return
  end
  if step.file then
    open_file_step(tour, step)
  else
    marks.clear_all()
  end
  local title = string.format(
    "%d/%d · %s%s",
    state.active_step_index(),
    #tour.steps,
    step.title or tour.title,
    step.directory and (" · 📁 " .. step.directory) or (step.contents and " · 📝" or "")
  )
  local body = step.description or step.contents or ""
  ui.show({ title = title, body = body })
end

function M._progress_label()
  return string.format("▶ %d/%d", state.active_step_index() or 0, #(state.active_tour() and state.active_tour().steps or {}))
end

function M.start(tour)
  state.set_active_tour(tour)
  refresh()
end

function M.next()
  state.set_step_index((state.active_step_index() or 0) + 1)
  refresh()
end

function M.prev()
  state.set_step_index((state.active_step_index() or 0) - 1)
  refresh()
end

function M.goto_step(n)
  state.set_step_index(n)
  refresh()
end

function M.end_tour()
  ui.close()
  marks.clear_all()
  state.end_tour()
end

return M
