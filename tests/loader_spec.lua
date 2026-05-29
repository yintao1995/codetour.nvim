local loader = require("codetour.loader")
local util = require("codetour.util")

local FIXTURE_TOURS = vim.fn.getcwd() .. "/tests/fixtures/tours"

describe("loader.discover", function()
  it("scans the configured tours_dir non-recursively for *.tour", function()
    local tours = loader.discover(FIXTURE_TOURS)
    assert.equals(1, #tours)
    assert.matches("sample%.tour$", tours[1])
  end)

  it("returns empty list for nonexistent dir without throwing", function()
    assert.same({}, loader.discover("/nonexistent/dir"))
  end)
end)

describe("loader.load", function()
  it("parses a tour file and attaches source path", function()
    local tour = loader.load(FIXTURE_TOURS .. "/sample.tour")
    assert.equals("Sample Tour", tour.title)
    assert.equals("~/projects/codetour.nvim", tour.projectRoot)
    assert.equals(3, #tour.steps)
    assert.equals(FIXTURE_TOURS .. "/sample.tour", tour._path)
  end)

  it("rejects when steps missing", function()
    local tmp = vim.fn.tempname() .. ".tour"
    util.write_json(tmp, { title = "Bad", projectRoot = "/x" })
    local tour, err = loader.load(tmp)
    assert.is_nil(tour)
    assert.matches("steps", err)
  end)

  it("rejects when projectRoot missing", function()
    local tmp = vim.fn.tempname() .. ".tour"
    util.write_json(tmp, { title = "Bad", steps = {} })
    local tour, err = loader.load(tmp)
    assert.is_nil(tour)
    assert.matches("projectRoot", err)
  end)
end)

describe("loader.save", function()
  it("writes a tour back, dropping internal _path field", function()
    local tour = loader.load(FIXTURE_TOURS .. "/sample.tour")
    local tmp = vim.fn.tempname() .. ".tour"
    tour._path = tmp
    loader.save(tour)
    local raw = table.concat(vim.fn.readfile(tmp), "\n")
    assert.is_falsy(raw:find("_path"))
    assert.matches('"%$schema"', raw)
    assert.matches('"projectRoot"', raw)
    local pos_title = raw:find('"title"')
    local pos_root = raw:find('"projectRoot"')
    local pos_steps = raw:find('"steps"')
    assert.is_truthy(pos_title < pos_root and pos_root < pos_steps)
  end)
end)
