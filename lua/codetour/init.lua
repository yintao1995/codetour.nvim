local M = {}

M.version = "0.1.0"

M.config = {
  tours_dir = vim.fn.stdpath("data") .. "/codetour/tours",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
