local util = require("codetour.util")

describe("util.expand_path", function()
  it("expands ~ to HOME", function()
    assert.equals(vim.env.HOME .. "/foo", util.expand_path("~/foo"))
  end)
  it("returns absolute paths unchanged", function()
    assert.equals("/abs/x", util.expand_path("/abs/x"))
  end)
end)

describe("util.relative_to", function()
  it("returns slash-separated path relative to a given root", function()
    assert.equals("a/b.lua", util.relative_to("/root/a/b.lua", "/root"))
    assert.equals("a/b.lua", util.relative_to("/root/a/b.lua", "/root/"))
  end)

  it("returns nil when path is not under root", function()
    assert.is_nil(util.relative_to("/other/x", "/root"))
  end)

  it("expands ~ in root before comparing", function()
    local home_file = vim.env.HOME .. "/codetour-test.txt"
    assert.equals("codetour-test.txt", util.relative_to(home_file, "~"))
  end)
end)

describe("util.read_json / write_json", function()
  local tmp = vim.fn.tempname() .. ".json"

  it("writes pretty json with 2-space indent and trailing newline", function()
    util.write_json(tmp, { title = "T", steps = { { line = 1 } } })
    local content = table.concat(vim.fn.readfile(tmp), "\n") .. "\n"
    assert.matches('^{\n  "title": "T",\n  "steps": %[\n    {\n      "line": 1\n    }\n  %]\n}\n$', content)
  end)

  it("reads json back into a table", function()
    util.write_json(tmp, { a = 1, b = "x" })
    local data = util.read_json(tmp)
    assert.equals(1, data.a)
    assert.equals("x", data.b)
  end)

  it("returns nil + error string for bad json", function()
    vim.fn.writefile({ "not json" }, tmp)
    local data, err = util.read_json(tmp)
    assert.is_nil(data)
    assert.is_string(err)
  end)
end)

describe("util.git_ref", function()
  it("returns nil outside a git repo", function()
    local ref = util.git_ref("/")
    assert.is_nil(ref)
  end)

  it("returns current ref string inside the codetour.nvim repo", function()
    local ref = util.git_ref(vim.fn.getcwd())
    assert.is_string(ref)
    assert.is_truthy(#ref > 0)
  end)
end)
