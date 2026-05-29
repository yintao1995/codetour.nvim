describe("codetour", function()
  it("loads as a module", function()
    local codetour = require("codetour")
    assert.is_table(codetour)
    assert.equals("0.1.0", codetour.version)
  end)

  it("default tours_dir resolves to stdpath(data)/codetour/tours", function()
    local expected = vim.fn.stdpath("data") .. "/codetour/tours"
    assert.equals(expected, require("codetour").config.tours_dir)
  end)

  it("setup() merges user opts", function()
    require("codetour").setup({ tours_dir = "/tmp/custom-tours" })
    assert.equals("/tmp/custom-tours", require("codetour").config.tours_dir)
  end)
end)
