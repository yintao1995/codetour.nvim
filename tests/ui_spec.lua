local ui = require("codetour.ui")

describe("codetour.ui", function()
  after_each(function()
    ui.close()
  end)

  it("show() opens a floating window with markdown buffer", function()
    ui.show({
      title = "1/3 · Entry",
      body = "Module **entry**",
    })
    local winid = ui.winid()
    assert.is_truthy(winid)
    assert.is_true(vim.api.nvim_win_is_valid(winid))
    local bufnr = vim.api.nvim_win_get_buf(winid)
    assert.equals("markdown", vim.bo[bufnr].filetype)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.equals("Module **entry**", lines[1])
  end)

  it("close() destroys window", function()
    ui.show({ title = "x", body = "y" })
    ui.close()
    assert.is_nil(ui.winid())
  end)

  it("show() reuses the existing window/buffer when called twice", function()
    ui.show({ title = "a", body = "b1" })
    local first = ui.winid()
    ui.show({ title = "a", body = "b2" })
    assert.equals(first, ui.winid())
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(first), 0, -1, false)
    assert.equals("b2", lines[1])
  end)
end)
