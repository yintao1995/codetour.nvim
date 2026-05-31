local M = {}

M.version = "0.1.0"

M.config = {
  tours_dir = vim.fn.stdpath("data") .. "/codetour/tours",
  qf_keymaps = {
    move_up = "<S-Up>",
    move_down = "<S-Down>",
    outdent = "<S-Left>",
    indent = "<S-Right>",
    delete = "dd",
    undo = "u",
    redo = "<C-r>",
    edit_tour = "e",
  },
}

local function set_default_hl()
  vim.api.nvim_set_hl(0, "CodeTourRuler", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CodeTourTree", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "CodeTourDesc", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CodeTourHint", { link = "Comment", default = true })
end

local QF_TITLE_PREFIX = "CodeTour: "

local KEY_DISPLAY = {
  ["<S-Up>"] = "S-↑",
  ["<S-Down>"] = "S-↓",
  ["<S-Left>"] = "S-←",
  ["<S-Right>"] = "S-→",
  ["<CR>"] = "↵",
  ["<Tab>"] = "Tab",
  ["<S-Tab>"] = "S-Tab",
  ["<C-r>"] = "C-r",
}

local function display_key(k)
  if not k or k == "" then return nil end
  return KEY_DISPLAY[k] or k
end

function M.format_qf_hint()
  local km = M.config.qf_keymaps or {}
  local parts = {}
  local up, down = display_key(km.move_up), display_key(km.move_down)
  if up and down then
    parts[#parts + 1] = string.format("%s/%s move", up, down)
  end
  local out, ind = display_key(km.outdent), display_key(km.indent)
  if out and ind then
    parts[#parts + 1] = string.format("%s/%s depth", out, ind)
  end
  local del = display_key(km.delete)
  if del then
    parts[#parts + 1] = string.format("%s del", del)
  end
  local u, r = display_key(km.undo), display_key(km.redo)
  if u and r then
    parts[#parts + 1] = string.format("%s/%s undo", u, r)
  elseif u then
    parts[#parts + 1] = string.format("%s undo", u)
  end
  local ed = display_key(km.edit_tour)
  if ed then
    parts[#parts + 1] = string.format("%s edit", ed)
  end
  return table.concat(parts, "  ")
end

local function bind_qf_keymaps(bufnr)
  local qf = vim.fn.getqflist({ title = 1 })
  if not (qf.title and qf.title:sub(1, #QF_TITLE_PREFIX) == QF_TITLE_PREFIX) then
    return
  end
  local km = M.config.qf_keymaps or {}
  local function map(lhs, fn, desc)
    if not lhs or lhs == "" then return end
    vim.keymap.set("n", lhs, fn, {
      buffer = bufnr,
      nowait = true,
      silent = true,
      noremap = true,
      desc = desc,
    })
  end
  local function with_lnum(fn)
    return function()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      fn(lnum)
    end
  end
  local editor = require("codetour.editor")
  map(km.move_up, with_lnum(editor.move_step_up), "CodeTour: move step up")
  map(km.move_down, with_lnum(editor.move_step_down), "CodeTour: move step down")
  map(km.indent, with_lnum(editor.indent_step), "CodeTour: indent step (depth+1)")
  map(km.outdent, with_lnum(editor.outdent_step), "CodeTour: outdent step (depth-1)")
  map(km.delete, with_lnum(editor.delete_step), "CodeTour: delete step")
  map(km.undo, with_lnum(editor.undo), "CodeTour: undo last edit")
  map(km.redo, with_lnum(editor.redo), "CodeTour: redo")
  map(km.edit_tour, function() editor.edit_tour_file() end, "CodeTour: edit .tour file")
end

local function unbind_qf_keymaps(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local km = M.config.qf_keymaps or {}
  for _, lhs in pairs(km) do
    if type(lhs) == "string" and lhs ~= "" then
      pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
    end
  end
end

-- 每次 qf buffer 显示或 list 变化时调用: 先清空我们留下的 keymap 和 extmark,
-- 再根据当前 list 的 title 决定是否重新装载 CodeTour 的高亮和键位
local function refresh_qf_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if vim.bo[bufnr].buftype ~= "quickfix" then return end
  unbind_qf_keymaps(bufnr)
  require("codetour.runner").apply_highlights(bufnr) -- 内部先清 namespace, 再按需 apply
  bind_qf_keymaps(bufnr) -- 内部判断 title, 非 CodeTour 不绑
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.fn.mkdir(M.config.tours_dir, "p")
  _G.codetour_qftf = function(info)
    return require("codetour.runner").qftf(info)
  end
  vim.o.quickfixtextfunc = "v:lua.codetour_qftf"

  set_default_hl()
  local grp = vim.api.nvim_create_augroup("codetour_qf", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = grp,
    callback = set_default_hl,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    group = grp,
    callback = function(args)
      vim.schedule(function() refresh_qf_buffer(args.buf) end)
    end,
  })
  -- 切换其他 quickfix list (vimgrep / setqflist 等) 时 qf buffer 复用, FileType 不会再触发,
  -- 用 BufWinEnter 覆盖窗口再次显示场景; 用 QuickFixCmdPost 覆盖 list 内容被外部命令换掉的场景
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = grp,
    callback = function(args)
      if vim.bo[args.buf].buftype ~= "quickfix" then return end
      vim.schedule(function() refresh_qf_buffer(args.buf) end)
    end,
  })
  vim.api.nvim_create_autocmd("QuickFixCmdPost", {
    group = grp,
    callback = function()
      vim.schedule(function()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local b = vim.api.nvim_win_get_buf(w)
          if vim.bo[b].buftype == "quickfix" then
            refresh_qf_buffer(b)
          end
        end
      end)
    end,
  })
  -- 用户在外部编辑器（或我们打开的 .tour 文件中）保存了 active tour 文件 → 自动重载并刷新 quickfix
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = grp,
    callback = function(args)
      local active = require("codetour.state").active_tour()
      if not active or not active._path then return end
      local saved_abs = vim.fn.fnamemodify(args.file, ":p")
      local tour_abs = vim.fn.fnamemodify(active._path, ":p")
      if saved_abs ~= tour_abs then return end
      local fresh, err = require("codetour.loader").load(active._path)
      if not fresh then
        vim.notify("CodeTour: 重新加载 .tour 失败：" .. tostring(err), vim.log.levels.ERROR)
        return
      end
      require("codetour.state").set_active_tour(fresh)
      require("codetour.runner").refresh_quickfix(fresh)
      vim.notify("CodeTour: 已根据 " .. vim.fs.basename(active._path) .. " 重新加载并刷新 quickfix")
    end,
  })
end

M.start = function(...)
  return require("codetour.runner").start(...)
end
M.end_tour = function()
  return require("codetour.runner").end_tour()
end
M.pick = function()
  return require("codetour.picker").pick_tour()
end

return M
