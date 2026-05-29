local M = {}

local _win, _buf

local function ensure_buf()
  if _buf and vim.api.nvim_buf_is_valid(_buf) then
    return _buf
  end
  _buf = vim.api.nvim_create_buf(false, true)
  vim.bo[_buf].buftype = "nofile"
  vim.bo[_buf].bufhidden = "wipe"
  vim.bo[_buf].filetype = "markdown"

  vim.keymap.set("n", "<CR>", function()
    require("codetour.ui").activate_link_under_cursor()
  end, { buffer = _buf, nowait = true })

  vim.keymap.set("n", "q", function()
    require("codetour.runner").end_tour()
  end, { buffer = _buf, nowait = true })

  vim.keymap.set("n", "n", function()
    require("codetour.runner").next()
  end, { buffer = _buf, nowait = true })

  vim.keymap.set("n", "p", function()
    require("codetour.runner").prev()
  end, { buffer = _buf, nowait = true })

  return _buf
end

local function ensure_win()
  if _win and vim.api.nvim_win_is_valid(_win) then
    return _win
  end
  local buf = ensure_buf()
  local cols = vim.o.columns
  local rows = vim.o.lines
  local width = math.max(40, math.floor(cols * 0.4))
  local height = math.max(8, math.floor(rows * 0.3))
  _win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    anchor = "SE",
    row = rows - 2,
    col = cols - 2,
    width = width,
    height = height,
    border = "rounded",
    title = " CodeTour ",
    title_pos = "left",
    style = "minimal",
    focusable = true,
  })
  vim.wo[_win].wrap = true
  vim.wo[_win].linebreak = true
  return _win
end

function M.winid()
  if _win and vim.api.nvim_win_is_valid(_win) then
    return _win
  end
  return nil
end

function M.show(opts)
  local win = ensure_win()
  local buf = vim.api.nvim_win_get_buf(win)
  pcall(vim.api.nvim_win_set_config, win, { title = " " .. (opts.title or "CodeTour") .. " " })
  vim.bo[buf].modifiable = true
  local lines = vim.split(opts.body or "", "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.close()
  if _win and vim.api.nvim_win_is_valid(_win) then
    pcall(vim.api.nvim_win_close, _win, true)
  end
  _win = nil
  if _buf and vim.api.nvim_buf_is_valid(_buf) then
    pcall(vim.api.nvim_buf_delete, _buf, { force = true })
  end
  _buf = nil
end

function M.activate_link_under_cursor()
  local win = M.winid()
  if not win then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local ok, md = pcall(require, "codetour.markdown")
  if not ok then
    return
  end
  local links = md.extract_links(line)
  for _, l in ipairs(links) do
    if l.range and col + 1 >= l.range[1] and col + 1 <= l.range[2] then
      if l.kind == "step_ref" then
        require("codetour.runner").goto_step(l.step)
        return
      end
    end
  end
  for _, l in ipairs(links) do
    if l.kind == "shell" and line:match("^%s*>>") then
      vim.cmd("split | terminal " .. l.command)
      return
    end
    if l.kind == "command" then
      vim.notify("CodeTour: command link not bound: " .. l.command, vim.log.levels.WARN)
      return
    end
  end
end

return M
