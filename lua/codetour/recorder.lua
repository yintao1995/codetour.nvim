local util = require("codetour.util")
local loader = require("codetour.loader")
local state = require("codetour.state")

local M = {}

local function slugify(s)
  return s:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
end

local function tilde_compress(abs)
  local home = vim.env.HOME
  if abs:sub(1, #home) == home then
    return "~" .. abs:sub(#home + 1)
  end
  return abs
end

function M.new_tour(opts)
  local config = require("codetour").config
  local cwd = vim.fn.getcwd()
  local tour = {
    ["$schema"] = "https://aka.ms/codetour-schema",
    title = opts.title,
    description = opts.description,
    projectRoot = tilde_compress(cwd),
    steps = setmetatable({}, { __jsontype = "array" }),
    _path = config.tours_dir .. "/" .. slugify(opts.title) .. ".tour",
  }
  loader.save(tour)
  state.set_active_tour(tour)
  return tour
end

function M.add_step(description)
  local tour = state.active_tour()
  assert(tour, "no active tour")
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    error("buffer has no file name")
  end
  local rel = util.relative_to(bufname, tour.projectRoot)
  if not rel then
    error(string.format("buffer %s is outside projectRoot %s", bufname, tour.projectRoot))
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local step = {
    file = rel,
    line = row,
    description = description or "",
  }
  table.insert(tour.steps, step)
  loader.save(tour)
  return step
end

function M.delete_step(idx)
  local tour = state.active_tour()
  assert(tour, "no active tour")
  table.remove(tour.steps, idx)
  loader.save(tour)
end

function M.edit_description(idx, new_desc)
  local tour = state.active_tour()
  assert(tour, "no active tour")
  tour.steps[idx].description = new_desc
  loader.save(tour)
end

return M
