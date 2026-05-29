local M = {}

M.version = "0.1.0"

M.config = {
  tours_dir = vim.fn.stdpath("data") .. "/codetour/tours",
}

local function set_default_hl()
  vim.api.nvim_set_hl(0, "CodeTourRuler", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "CodeTourTree", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "CodeTourDesc", { link = "Comment", default = true })
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
      vim.schedule(function()
        require("codetour.runner").apply_highlights(args.buf)
      end)
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
