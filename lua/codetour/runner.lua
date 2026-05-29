local state = require("codetour.state")
local marks = require("codetour.marks")
local ui = require("codetour.ui")
local loader = require("codetour.loader")

local M = {}

local _global_keymaps_installed = false
local _saved_keymaps = {}

local function install_global_keymaps()
  if _global_keymaps_installed then
    return
  end
  _saved_keymaps = {}
  for _, lhs in ipairs({ "n", "p", "q" }) do
    local existing = vim.fn.maparg(lhs, "n", false, true)
    if existing and not vim.tbl_isempty(existing) then
      _saved_keymaps[lhs] = existing
    end
  end
  vim.keymap.set("n", "n", function() M.next() end, { desc = "CodeTour: next step" })
  vim.keymap.set("n", "p", function() M.prev() end, { desc = "CodeTour: prev step" })
  vim.keymap.set("n", "q", function() M.end_tour() end, { desc = "CodeTour: end tour" })
  _global_keymaps_installed = true
end

local function uninstall_global_keymaps()
  if not _global_keymaps_installed then
    return
  end
  for _, lhs in ipairs({ "n", "p", "q" }) do
    pcall(vim.keymap.del, "n", lhs)
    local saved = _saved_keymaps[lhs]
    if saved and saved.rhs then
      pcall(vim.fn.mapset, "n", false, saved)
    end
  end
  _saved_keymaps = {}
  _global_keymaps_installed = false
end

local function focus_non_float()
  local cur = vim.api.nvim_get_current_win()
  local cfg = vim.api.nvim_win_get_config(cur)
  if cfg.relative == "" then
    return
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      vim.api.nvim_set_current_win(w)
      return
    end
  end
end

local function open_file_step(tour, step)
  focus_non_float()
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
  install_global_keymaps()
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
  uninstall_global_keymaps()
  ui.close()
  marks.clear_all()
  state.end_tour()
end

return M
