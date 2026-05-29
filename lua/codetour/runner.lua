local state = require("codetour.state")
local loader = require("codetour.loader")

local M = {}

local QF_TITLE_PREFIX = "CodeTour: "

local function basename_of(rel)
  return vim.fs.basename(rel)
end

local function prefix_of(depth)
  return string.rep("│   ", depth or 0) .. "├── "
end

local function pad_right(s, target_w)
  local w = vim.fn.strdisplaywidth(s)
  if w >= target_w then
    return s
  end
  return s .. string.rep(" ", target_w - w)
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

local function build_depth_ruler(max_depth)
  local parts = { string.rep(" ", 4) } -- 跳过 "├── " 让数字与 marker 起点对齐
  for d = 0, max_depth do
    parts[#parts + 1] = string.format("%-4d", d)
  end
  return (table.concat(parts):gsub("%s+$", ""))
end

local function tour_to_items(tour)
  local root = loader.project_root_abs(tour)
  local max_depth = 0
  for _, step in ipairs(tour.steps) do
    local d = step.depth or 0
    if d > max_depth then
      max_depth = d
    end
  end
  local items = {
    {
      valid = 0,
      text = build_depth_ruler(max_depth),
      user_data = { kind = "ruler" },
    },
    {
      valid = 0,
      text = tour.title,
      user_data = { kind = "header" },
    },
  }
  for _, step in ipairs(tour.steps) do
    table.insert(items, step_to_qf_item(root, step))
  end
  return items
end

local function compute_column_widths(items)
  local marker_section_w, fileline_w = 0, 0
  for _, it in ipairs(items) do
    local ud = it.user_data
    if ud and ud.kind == "step" then
      local section = prefix_of(ud.depth) .. (ud.marker or "")
      marker_section_w = math.max(marker_section_w, vim.fn.strdisplaywidth(section))
      fileline_w = math.max(fileline_w, vim.fn.strdisplaywidth(ud.fileline or ""))
    end
  end
  return marker_section_w + 4, fileline_w + 4
end

local function items_to_lines(items, start_idx, end_idx)
  local marker_section_w, fileline_w = compute_column_widths(items)

  local lines = {}
  for idx = start_idx, end_idx do
    local it = items[idx] or {}
    local ud = it.user_data or {}
    if ud.kind == "ruler" or ud.kind == "header" then
      table.insert(lines, it.text or "")
    elseif ud.kind == "step" then
      local section = prefix_of(ud.depth) .. (ud.marker or "")
      local marker_block = pad_right(section, marker_section_w)
      table.insert(lines, marker_block .. pad_right(ud.fileline or "", fileline_w) .. (it.text or ""))
    else
      table.insert(lines, it.text or "")
    end
  end
  return lines
end

local HL_NS = vim.api.nvim_create_namespace("codetour_qf_hl")

function M.apply_highlights_to_buf(bufnr, items)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, HL_NS, 0, -1)

  local marker_section_w, fileline_w = compute_column_widths(items)

  for line_idx, item in ipairs(items) do
    local ud = item.user_data or {}
    local row = line_idx - 1

    if ud.kind == "ruler" then
      pcall(vim.api.nvim_buf_add_highlight, bufnr, HL_NS, "CodeTourRuler", row, 0, -1)
    elseif ud.kind == "step" then
      local section = prefix_of(ud.depth) .. (ud.marker or "")
      local marker_block_byte = #section + (marker_section_w - vim.fn.strdisplaywidth(section))
      local fileline = ud.fileline or ""
      local fileline_block_byte_end = marker_block_byte + #fileline + (fileline_w - vim.fn.strdisplaywidth(fileline))

      pcall(vim.api.nvim_buf_add_highlight, bufnr, HL_NS, "CodeTourTree", row, 0, marker_block_byte)
      pcall(vim.api.nvim_buf_add_highlight, bufnr, HL_NS, "CodeTourDesc", row, fileline_block_byte_end, -1)
    end
  end
end

function M.apply_highlights(bufnr)
  local qf = vim.fn.getqflist({ title = 1, items = 1 })
  if not (qf.title and qf.title:sub(1, #QF_TITLE_PREFIX) == QF_TITLE_PREFIX) then
    return
  end
  M.apply_highlights_to_buf(bufnr, qf.items)
end

function M.render_tour_lines(tour)
  local items = tour_to_items(tour)
  return items_to_lines(items, 1, #items)
end

function M.tour_items(tour)
  return tour_to_items(tour)
end

function M.populate_quickfix(tour)
  vim.fn.setqflist({}, " ", {
    title = QF_TITLE_PREFIX .. tour.title,
    items = tour_to_items(tour),
  })
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
  return items_to_lines(qf.items, info.start_idx, info.end_idx)
end

function M.start(tour)
  state.set_active_tour(tour)
  M.populate_quickfix(tour)
  vim.cmd("botright copen")
  pcall(vim.cmd, "cfirst")
end

function M.end_tour()
  pcall(vim.cmd, "cclose")
  state.end_tour()
end

return M
