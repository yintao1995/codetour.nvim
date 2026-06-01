local M = {}

local _tour = nil
local _step_idx = nil
local _anchor = nil
local _listeners = {}

function M.reset()
  _tour = nil
  _step_idx = nil
  _anchor = nil
  _listeners = {}
end

function M.get_anchor()
  return _anchor
end

function M.set_anchor(idx)
  if not _tour or not idx then _anchor = nil; return end
  if idx < 1 or idx > #_tour.steps then _anchor = nil; return end
  _anchor = idx
end

function M.clear_anchor()
  _anchor = nil
end

function M.on(event, cb)
  _listeners[event] = _listeners[event] or {}
  table.insert(_listeners[event], cb)
end

local function emit(event, ...)
  for _, cb in ipairs(_listeners[event] or {}) do
    cb(...)
  end
end

function M.active_tour()
  return _tour
end

function M.active_step_index()
  return _step_idx
end

function M.active_step()
  if not _tour or not _step_idx then
    return nil
  end
  return _tour.steps[_step_idx]
end

function M.set_active_tour(tour)
  _tour = tour
  _step_idx = 1
  _anchor = nil
  emit("tour_started", tour)
  emit("step_changed", _step_idx)
end

function M.set_step_index(i)
  if not _tour then
    return
  end
  i = math.max(1, math.min(#_tour.steps, i))
  _step_idx = i
  emit("step_changed", i)
end

function M.end_tour()
  local prev = _tour
  _tour = nil
  _step_idx = nil
  _anchor = nil
  emit("tour_ended", prev)
end

return M
