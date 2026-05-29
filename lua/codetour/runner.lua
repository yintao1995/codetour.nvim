local state = require("codetour.state")
local loader = require("codetour.loader")

local M = {}

local function step_to_qf_item(root, step)
  if step.file then
    return {
      filename = root .. "/" .. step.file,
      lnum = step.line or 1,
      col = 1,
      text = step.description or step.title or "",
    }
  elseif step.directory then
    return {
      filename = root .. "/" .. step.directory,
      lnum = 1,
      col = 1,
      text = "[dir] " .. (step.description or step.title or ""),
    }
  elseif step.contents then
    return {
      valid = 0,
      text = (step.title and ("[" .. step.title .. "] ") or "") .. (step.description or step.contents),
    }
  end
  return { valid = 0, text = "(empty step)" }
end

function M.populate_quickfix(tour)
  local root = loader.project_root_abs(tour)
  local items = {}
  for _, step in ipairs(tour.steps) do
    table.insert(items, step_to_qf_item(root, step))
  end
  vim.fn.setqflist({}, " ", {
    title = "CodeTour: " .. tour.title,
    items = items,
  })
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
