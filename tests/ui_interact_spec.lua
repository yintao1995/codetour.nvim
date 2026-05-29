local ui = require("codetour.ui")
local runner = require("codetour.runner")
local state = require("codetour.state")

describe("codetour.ui interaction", function()
  before_each(function()
    state.reset()
  end)

  it("invokes runner.goto_step when cursor sits on a step ref", function()
    runner.start({
      title = "T",
      projectRoot = vim.fn.getcwd(),
      _path = vim.fn.tempname() .. ".tour",
      steps = {
        { contents = "intro", description = "go to [#2]" },
        { contents = "two", description = "" },
      },
    })
    vim.api.nvim_set_current_win(ui.winid())
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(ui.winid()), 0, -1, false)
    local line_idx
    for i, l in ipairs(lines) do
      if l:find("%[#2%]") then
        line_idx = i
        break
      end
    end
    assert.is_truthy(line_idx)
    local col = lines[line_idx]:find("%[#2%]") - 1
    vim.api.nvim_win_set_cursor(ui.winid(), { line_idx, col })
    ui.activate_link_under_cursor()
    assert.equals(2, state.active_step_index())
  end)
end)
