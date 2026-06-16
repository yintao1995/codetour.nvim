local runner = require("codetour.runner")
local state = require("codetour.state")

local PROJECT = vim.fn.getcwd()

local function make_tour()
  return {
    title = "demo",
    projectRoot = PROJECT,
    _path = vim.fn.tempname() .. ".tour",
    steps = {
      { file = "lua/codetour/init.lua", line = 3, title = "AAAA1", description = "step1", depth = 0 },
      { file = "lua/codetour/util.lua", line = 12, title = "AAAA2", description = "step2", depth = 1 },
      { file = "lua/codetour/runner.lua", line = 1, title = "AAAA3", description = "step3", depth = 1 },
      { file = "lua/codetour/state.lua", line = 5, title = "AAAA4", description = "step4", depth = 0 },
    },
  }
end

describe("codetour.runner (quickfix-driven)", function()
  before_each(function()
    state.reset()
    vim.fn.setqflist({}, "f")
    pcall(vim.cmd, "cclose")
  end)

  it("populate_quickfix adds ruler + header + entries with user_data", function()
    runner.populate_quickfix(make_tour())
    local qf = vim.fn.getqflist({ items = 1, title = 1 })
    assert.equals("CodeTour: demo", qf.title)
    assert.equals(6, #qf.items)

    -- ruler
    local r = qf.items[1]
    assert.equals(0, r.valid)
    assert.equals("ruler", r.user_data.kind)
    assert.matches("^%s+1%s+2$", r.text)

    -- header
    local h = qf.items[2]
    assert.equals(0, h.valid)
    assert.equals("demo", h.text)
    assert.equals("header", h.user_data.kind)

    -- first step
    local s1 = qf.items[3]
    assert.matches("lua/codetour/init%.lua$", vim.api.nvim_buf_get_name(s1.bufnr))
    assert.equals(3, s1.lnum)
    assert.equals("step1", s1.text)
    assert.equals("step", s1.user_data.kind)
    assert.equals("AAAA1", s1.user_data.marker)
    assert.equals(0, s1.user_data.depth)
    assert.equals("init.lua:3", s1.user_data.fileline)

    -- nested step
    local s2 = qf.items[4]
    assert.equals(1, s2.user_data.depth)
    assert.equals("util.lua:12", s2.user_data.fileline)
  end)

  it("qftf renders ruler + header + tree-style step lines", function()
    runner.populate_quickfix(make_tour())
    local qf = vim.fn.getqflist({ id = 0, items = 1 })
    local lines = runner.qftf({
      quickfix = 1,
      id = vim.fn.getqflist({ id = 0 }).id,
      start_idx = 1,
      end_idx = #qf.items,
    })
    assert.equals(6, #lines)
    assert.matches("^%s+1%s+2$", lines[1])
    assert.equals("demo", lines[2])
    assert.matches("^├── AAAA1%s+init%.lua:3%s+step1", lines[3])
    assert.matches("^│   ├── AAAA2%s+util%.lua:12%s+step2", lines[4])
    assert.matches("^│   ├── AAAA3%s+runner%.lua:1%s+step3", lines[5])
    assert.matches("^├── AAAA4%s+state%.lua:5%s+step4", lines[6])
  end)

  it("qftf returns nil for non-codetour qf lists", function()
    vim.fn.setqflist({}, " ", { title = "vimgrep something", items = {} })
    local id = vim.fn.getqflist({ id = 0 }).id
    local result = runner.qftf({ quickfix = 1, id = id, start_idx = 1, end_idx = 0 })
    assert.is_nil(result)
  end)

  it("qftf aligns fileline and description columns across depths", function()
    runner.populate_quickfix({
      title = "alignment",
      projectRoot = PROJECT,
      _path = vim.fn.tempname() .. ".tour",
      steps = {
        { file = "lua/codetour/init.lua", line = 1, title = "short", depth = 0, description = "d1" },
        { file = "lua/codetour/util.lua", line = 2, title = "muchLonger", depth = 1, description = "d2" },
        { file = "lua/codetour/state.lua", line = 3, title = "x", depth = 2, description = "d3" },
      },
    })
    local qf = vim.fn.getqflist({ id = 0, items = 1 })
    local lines = runner.qftf({
      quickfix = 1,
      id = vim.fn.getqflist({ id = 0 }).id,
      start_idx = 1,
      end_idx = #qf.items,
    })

    local function display_col_of(line, needle)
      local b = line:find(needle, 1, true)
      if not b then return nil end
      return vim.fn.strdisplaywidth(line:sub(1, b - 1))
    end

    local cols = {
      display_col_of(lines[3], "init.lua:"),
      display_col_of(lines[4], "util.lua:"),
      display_col_of(lines[5], "state.lua:"),
    }
    assert.is_truthy(cols[1])
    for i = 2, 3 do
      assert.equals(cols[1], cols[i],
        string.format("fileline col mismatch line %d: got %s vs %s", i + 2, tostring(cols[i]), tostring(cols[1])))
    end

    local desc_cols = {
      display_col_of(lines[3], "d1"),
      display_col_of(lines[4], "d2"),
      display_col_of(lines[5], "d3"),
    }
    for i = 2, 3 do
      assert.equals(desc_cols[1], desc_cols[i],
        string.format("desc col mismatch line %d: got %s vs %s", i + 2, tostring(desc_cols[i]), tostring(desc_cols[1])))
    end
  end)

  it("start() opens quickfix window", function()
    runner.start(make_tour())
    local has_qf = false
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "quickfix" then
        has_qf = true
        break
      end
    end
    assert.is_true(has_qf)
  end)

  it("end_tour closes quickfix and clears state", function()
    runner.start(make_tour())
    runner.end_tour()
    assert.is_nil(state.active_tour())
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      assert.is_not.equals("quickfix", vim.bo[vim.api.nvim_win_get_buf(w)].buftype)
    end
  end)

  it("render_tour_lines returns same shape as qftf without touching qflist", function()
    local before_id = vim.fn.getqflist({ id = 0 }).id
    local lines = runner.render_tour_lines(make_tour())
    assert.equals(before_id, vim.fn.getqflist({ id = 0 }).id)
    assert.equals(6, #lines)
    assert.matches("^%s+1%s+2$", lines[1])
    assert.equals("demo", lines[2])
    assert.matches("^├── AAAA1%s+init%.lua:3%s+step1", lines[3])
  end)
end)
