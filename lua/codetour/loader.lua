local util = require("codetour.util")

local M = {}

function M.discover(tours_dir)
  local tours = {}
  local fd = vim.uv.fs_scandir(tours_dir)
  if not fd then
    return tours
  end
  while true do
    local name, t = vim.uv.fs_scandir_next(fd)
    if not name then
      break
    end
    if t == "file" and name:sub(-5) == ".tour" then
      table.insert(tours, tours_dir .. "/" .. name)
    end
  end
  table.sort(tours)
  return tours
end

local function validate(tour)
  if type(tour.title) ~= "string" or tour.title == "" then
    return "missing title"
  end
  if type(tour.projectRoot) ~= "string" or tour.projectRoot == "" then
    return "missing projectRoot"
  end
  if type(tour.steps) ~= "table" then
    return "missing steps array"
  end
  return nil
end

function M.load(path)
  local data, err = util.read_json(path)
  if not data then
    return nil, err
  end
  err = validate(data)
  if err then
    return nil, err
  end
  for _, step in ipairs(data.steps) do
    if step.depth == nil then
      step.depth = 0
    end
  end
  data._path = path
  return data
end

function M.save(tour)
  assert(tour._path, "tour._path is required for save()")
  local copy = vim.deepcopy(tour)
  for k in pairs(copy) do
    if type(k) == "string" and k:sub(1, 1) == "_" then
      copy[k] = nil
    end
  end
  util.write_json(tour._path, copy)
end

function M.project_root_abs(tour)
  return util.expand_path(tour.projectRoot)
end

return M
