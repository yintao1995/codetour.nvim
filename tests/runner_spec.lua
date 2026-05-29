local runner = require("codetour.runner")
local state = require("codetour.state")
local marks = require("codetour.marks")

local PROJECT = vim.fn.getcwd()

local function make_tour()
  return {
    title = "Test",
    projectRoot = PROJECT,
    _path = vim.fn.tempname() .. ".tour",
    steps = {
      { file = "lua/codetour/init.lua", line = 3, description = "step1" },
      { contents = "Just text", description = "step2" },
      { file = "lua/codetour/util.lua", line = 1, description = "step3" },
    },
  }
end

describe("codetour.runner", function()
  before_each(function()
    state.reset()
    marks.clear_all()
  end)

  local function code_win()
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(w).relative == "" then
        return w
      end
    end
  end

  local function code_buf_name()
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(code_win()))
  end

  it("start() opens projectRoot+file at the right line", function()
    runner.start(make_tour())
    assert.equals(1, state.active_step_index())
    assert.matches("lua/codetour/init%.lua$", code_buf_name())
    local row = vim.api.nvim_win_get_cursor(code_win())[1]
    assert.equals(3, row)
  end)

  it("next() to a content step does NOT change file buffer", function()
    runner.start(make_tour())
    local before = code_buf_name()
    runner.next()
    assert.equals(2, state.active_step_index())
    assert.equals(before, code_buf_name())
  end)

  it("next() then next() jumps to util.lua line 1", function()
    runner.start(make_tour())
    runner.next()
    runner.next()
    assert.equals(3, state.active_step_index())
    assert.matches("lua/codetour/util%.lua$", code_buf_name())
    assert.equals(1, vim.api.nvim_win_get_cursor(code_win())[1])
  end)

  it("prev() at step 1 stays at step 1", function()
    runner.start(make_tour())
    runner.prev()
    assert.equals(1, state.active_step_index())
  end)

  it("end_tour() clears state and marks", function()
    runner.start(make_tour())
    runner.end_tour()
    assert.is_nil(state.active_tour())
  end)

  it("goto_step(n) jumps directly", function()
    runner.start(make_tour())
    runner.goto_step(3)
    assert.equals(3, state.active_step_index())
  end)

  it("works regardless of current cwd (uses tour.projectRoot)", function()
    local original = vim.fn.getcwd()
    pcall(function()
      vim.cmd("cd /tmp")
      runner.start(make_tour())
      assert.matches("lua/codetour/init%.lua$", code_buf_name())
    end)
    vim.cmd("cd " .. original)
  end)
end)
