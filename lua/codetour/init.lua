local M = {}

M.version = "0.1.0"

M.config = {
  tours_dir = vim.fn.stdpath("data") .. "/codetour/tours",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.fn.mkdir(M.config.tours_dir, "p")
  _G.codetour_qftf = function(info)
    return require("codetour.runner").qftf(info)
  end
  vim.o.quickfixtextfunc = "v:lua.codetour_qftf"
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
