local marks = require("codetour.marks")

describe("codetour.marks", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line1", "line2", "line3" })
    marks.clear_all()
  end)

  it("set places virt_text on a 1-based line", function()
    marks.set(bufnr, 2, "▶ 1/3")
    local ns = marks.namespace()
    local got = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    assert.equals(1, #got)
    assert.equals(1, got[1][2])
    local virt = got[1][4].virt_text
    assert.equals("▶ 1/3", virt[1][1])
  end)

  it("clear_all removes all marks", function()
    marks.set(bufnr, 1, "x")
    marks.clear_all()
    local ns = marks.namespace()
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}))
  end)
end)
