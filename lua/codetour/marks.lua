local M = {}

local NS = vim.api.nvim_create_namespace("codetour.marks")
local _tracked_bufs = {}

function M.namespace()
  return NS
end

function M.set(bufnr, line_1based, label)
  local row = line_1based - 1
  vim.api.nvim_buf_set_extmark(bufnr, NS, row, 0, {
    sign_text = "▶",
    sign_hl_group = "DiagnosticInfo",
    virt_text = { { label, "DiagnosticInfo" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
  _tracked_bufs[bufnr] = true
end

function M.clear_all()
  for buf, _ in pairs(_tracked_bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    end
  end
  _tracked_bufs = {}
end

return M
