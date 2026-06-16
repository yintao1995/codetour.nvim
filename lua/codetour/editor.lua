local state = require("codetour.state")
local loader = require("codetour.loader")
local runner = require("codetour.runner")

local M = {}

-- quickfix 行号到 step 索引的偏移：第 1 行是 ruler，第 2 行是 header
local STEP_OFFSET = 2
local MAX_HISTORY = 100

local function qf_lnum_to_step_idx(qf_lnum)
  return qf_lnum - STEP_OFFSET
end

local function step_idx_to_qf_lnum(step_idx)
  return step_idx + STEP_OFFSET
end

local function ensure_active()
  local tour = state.active_tour()
  if not tour then
    vim.notify("CodeTour: 当前没有活跃的 tour", vim.log.levels.WARN)
    return nil
  end
  return tour
end

local function clamp_idx(tour, idx)
  if idx < 1 or idx > #tour.steps then
    return nil
  end
  return idx
end

local function push_history(tour, qf_lnum)
  tour._history = tour._history or {}
  tour._future = {} -- 任何新动作都清空 redo 栈
  table.insert(tour._history, {
    steps = vim.deepcopy(tour.steps),
    lnum = qf_lnum,
  })
  while #tour._history > MAX_HISTORY do
    table.remove(tour._history, 1)
  end
end

function M.move_step_up(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  local idx = clamp_idx(tour, qf_lnum_to_step_idx(qf_lnum))
  if not idx or idx <= 1 then
    return
  end
  push_history(tour, qf_lnum)
  tour.steps[idx], tour.steps[idx - 1] = tour.steps[idx - 1], tour.steps[idx]
  loader.save(tour)
  runner.refresh_quickfix(tour, step_idx_to_qf_lnum(idx - 1))
end

function M.move_step_down(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  local idx = clamp_idx(tour, qf_lnum_to_step_idx(qf_lnum))
  if not idx or idx >= #tour.steps then
    return
  end
  push_history(tour, qf_lnum)
  tour.steps[idx], tour.steps[idx + 1] = tour.steps[idx + 1], tour.steps[idx]
  loader.save(tour)
  runner.refresh_quickfix(tour, step_idx_to_qf_lnum(idx + 1))
end

function M.indent_step(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  local idx = clamp_idx(tour, qf_lnum_to_step_idx(qf_lnum))
  if not idx then return end
  push_history(tour, qf_lnum)
  local step = tour.steps[idx]
  step.depth = (step.depth or 0) + 1
  loader.save(tour)
  runner.refresh_quickfix(tour, step_idx_to_qf_lnum(idx))
end

function M.outdent_step(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  local idx = clamp_idx(tour, qf_lnum_to_step_idx(qf_lnum))
  if not idx then return end
  local step = tour.steps[idx]
  local cur = step.depth or 0
  if cur <= 0 then
    return
  end
  push_history(tour, qf_lnum)
  step.depth = cur - 1
  loader.save(tour)
  runner.refresh_quickfix(tour, step_idx_to_qf_lnum(idx))
end

function M.delete_step(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  local idx = clamp_idx(tour, qf_lnum_to_step_idx(qf_lnum))
  if not idx then return end
  push_history(tour, qf_lnum)
  table.remove(tour.steps, idx)
  loader.save(tour)
  local new_idx = math.min(idx, #tour.steps)
  if new_idx < 1 then
    runner.refresh_quickfix(tour, STEP_OFFSET)
  else
    runner.refresh_quickfix(tour, step_idx_to_qf_lnum(new_idx))
  end
end

function M.undo(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  tour._history = tour._history or {}
  if #tour._history == 0 then
    vim.notify("CodeTour: 已经是最早状态", vim.log.levels.INFO)
    return
  end
  tour._future = tour._future or {}
  -- 当前状态推入 future，lnum 记录此刻光标位置（redo 时回到这里）
  table.insert(tour._future, {
    steps = vim.deepcopy(tour.steps),
    lnum = qf_lnum,
  })
  local entry = table.remove(tour._history)
  tour.steps = entry.steps
  loader.save(tour)
  runner.refresh_quickfix(tour, entry.lnum or qf_lnum)
end

function M.redo(qf_lnum)
  local tour = ensure_active()
  if not tour then return end
  tour._future = tour._future or {}
  if #tour._future == 0 then
    vim.notify("CodeTour: 没有可重做的动作", vim.log.levels.INFO)
    return
  end
  tour._history = tour._history or {}
  table.insert(tour._history, {
    steps = vim.deepcopy(tour.steps),
    lnum = qf_lnum,
  })
  local entry = table.remove(tour._future)
  tour.steps = entry.steps
  loader.save(tour)
  runner.refresh_quickfix(tour, entry.lnum or qf_lnum)
end

M._STEP_OFFSET = STEP_OFFSET
M._MAX_HISTORY = MAX_HISTORY

-- 在 .tour JSON 文件中找到第 step_idx 个 step 对象的起始行号（1-based）
local function find_step_line(path, step_idx)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local in_steps = false
  local brace_depth = 0
  local step_count = 0
  local line_nr = 0
  for line in fd:lines() do
    line_nr = line_nr + 1
    if not in_steps then
      if line:find('"steps"%s*:%s*%[') then
        in_steps = true
      end
    else
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed then
        for i = 1, #trimmed do
          local c = trimmed:sub(i, i)
          if c == "{" then
            brace_depth = brace_depth + 1
            if brace_depth == 1 then
              step_count = step_count + 1
              if step_count == step_idx then
                fd:close()
                return line_nr
              end
            end
          elseif c == "}" then
            brace_depth = brace_depth - 1
            if brace_depth < 0 then break end
          end
        end
        if brace_depth < 0 then break end
      end
    end
  end
  fd:close()
  return nil
end

-- 在非 quickfix 的窗口里打开当前 active tour 的 .tour JSON 文件，让用户直接编辑
-- step_idx（可选）：传入时自动跳转到该 step 在 JSON 中的起始行
function M.edit_tour_file(step_idx)
  local tour = ensure_active()
  if not tour or not tour._path then return end
  -- 找一个非 qf 的窗口承载 tour 文件
  local target_win
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype ~= "quickfix" then
      target_win = w
      break
    end
  end
  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("vsplit")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(tour._path))
  if step_idx and step_idx >= 1 and step_idx <= #tour.steps then
    local line_nr = find_step_line(tour._path, step_idx)
    if line_nr then
      vim.api.nvim_win_set_cursor(0, { line_nr, 0 })
    end
  end
end

return M
