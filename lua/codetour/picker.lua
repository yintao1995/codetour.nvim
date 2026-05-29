local loader = require("codetour.loader")
local runner = require("codetour.runner")
local state = require("codetour.state")

local M = {}

local function load_all()
  local config = require("codetour").config
  local files = loader.discover(config.tours_dir)
  local items = {}
  for _, path in ipairs(files) do
    local tour, err = loader.load(path)
    if tour then
      table.insert(items, {
        text = string.format("%-30s  [%s]", tour.title, tour.projectRoot),
        tour = tour,
      })
    else
      vim.notify("CodeTour: 解析失败 " .. path .. ": " .. err, vim.log.levels.WARN)
    end
  end
  return items
end

local function pick(prompt, on_select)
  local items = load_all()
  if #items == 0 then
    vim.notify("CodeTour: tours_dir 下没有 .tour 文件", vim.log.levels.INFO)
    return
  end
  local ok = pcall(require, "snacks.picker")
  if ok then
    require("snacks.picker").pick({
      source = "codetour_tours",
      items = items,
      format = "text",
      preview = function(ctx)
        local tour = ctx.item and ctx.item.tour
        ctx.preview:reset()
        if not tour then
          ctx.preview:notify("no tour data", "error")
          return
        end
        ctx.preview:set_title(tour.title .. "  (" .. tour.projectRoot .. ")")
        local lines = require("codetour.runner").render_tour_lines(tour)
        ctx.preview:set_lines(lines)
      end,
      confirm = function(picker, item)
        picker:close()
        if item then
          on_select(item.tour)
        end
      end,
    })
    return
  end
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(it)
      return it.text
    end,
  }, function(choice)
    if choice then
      on_select(choice.tour)
    end
  end)
end

function M.pick_tour()
  pick("CodeTour", function(tour)
    runner.start(tour)
  end)
end

function M.pick_tour_for_resume()
  pick("Resume tour", function(tour)
    state.set_active_tour(tour)
    vim.notify(string.format(
      "CodeTour: 已激活 [%s] (%d steps)  现在用 :CodeTourAddStep 追加",
      tour.title,
      #tour.steps
    ))
  end)
end

function M.pick_step()
  local tour = state.active_tour()
  if not tour then
    return M.pick_tour()
  end
  local items = {}
  for i, step in ipairs(tour.steps) do
    table.insert(items, {
      text = string.format("%d. %s", i, step.title or step.description or step.file or step.contents or ""),
      idx = i,
    })
  end
  vim.ui.select(items, {
    prompt = "CodeTour Step",
    format_item = function(it)
      return it.text
    end,
  }, function(choice)
    if choice then
      runner.goto_step(choice.idx)
    end
  end)
end

return M
