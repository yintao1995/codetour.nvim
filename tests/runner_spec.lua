local runner = require("codetour.runner")
local state = require("codetour.state")
local loader = require("codetour.loader")

local PROJECT = vim.fn.getcwd()

local function make_tour()
  return {
    title = "Test",
    projectRoot = PROJECT,
    _path = vim.fn.tempname() .. ".tour",
    steps = {
      { file = "lua/codetour/init.lua", line = 3, description = "step1" },
      { contents = "Just text", title = "note", description = "step2" },
      { file = "lua/codetour/util.lua", line = 1, description = "step3" },
    },
  }
end

describe("codetour.runner (quickfix-driven)", function()
  before_each(function()
    state.reset()
    vim.fn.setqflist({}, "f")
    pcall(vim.cmd, "cclose")
  end)

  it("populate_quickfix produces one entry per step with correct fields", function()
    runner.populate_quickfix(make_tour())
    local qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert.equals("CodeTour: Test", qf.title)
    assert.equals(3, #qf.items)

    local i1 = qf.items[1]
    assert.matches("lua/codetour/init%.lua$", vim.api.nvim_buf_get_name(i1.bufnr))
    assert.equals(3, i1.lnum)
    assert.equals("step1", i1.text)

    local i2 = qf.items[2]
    assert.equals(0, i2.valid)
    assert.matches("note", i2.text)
    assert.matches("step2", i2.text)

    local i3 = qf.items[3]
    assert.matches("lua/codetour/util%.lua$", vim.api.nvim_buf_get_name(i3.bufnr))
    assert.equals(1, i3.lnum)
  end)

  it("start() opens quickfix window and jumps to first entry", function()
    runner.start(make_tour())
    local has_qf = false
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "quickfix" then
        has_qf = true
        break
      end
    end
    assert.is_true(has_qf)
    assert.equals(1, vim.fn.getqflist({ idx = 0 }).idx)
  end)

  it("next() advances quickfix idx (skipping invalid content entries)", function()
    runner.start(make_tour())
    runner.next()
    -- step 2 is content-only (valid=0), so cnext jumps directly to step 3
    assert.equals(3, vim.fn.getqflist({ idx = 0 }).idx)
  end)

  it("prev() decreases quickfix idx", function()
    runner.start(make_tour())
    runner.goto_step(3)
    runner.prev()
    -- step 2 invalid, prev goes back to 1
    assert.equals(1, vim.fn.getqflist({ idx = 0 }).idx)
  end)

  it("goto_step(n) jumps to entry n", function()
    runner.start(make_tour())
    runner.goto_step(3)
    assert.equals(3, vim.fn.getqflist({ idx = 0 }).idx)
  end)

  it("end_tour() closes quickfix and clears state", function()
    runner.start(make_tour())
    runner.end_tour()
    assert.is_nil(state.active_tour())
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      assert.is_not.equals("quickfix", vim.bo[vim.api.nvim_win_get_buf(w)].buftype)
    end
  end)
end)
