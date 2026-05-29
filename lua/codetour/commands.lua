local M = {}

function M.register()
  local function cmd(name, fn, opts)
    vim.api.nvim_create_user_command(name, fn, opts or {})
  end

  cmd("CodeTourStart", function()
    require("codetour.picker").pick_tour()
  end, { desc = "选择并开始一个 tour" })

  cmd("CodeTourEnd", function()
    require("codetour.runner").end_tour()
  end, { desc = "退出当前 tour" })

  cmd("CodeTourNew", function(args)
    local title = args.args
    if title == "" then
      title = vim.fn.input("Tour title: ")
    end
    if title == "" then
      return
    end
    local tour = require("codetour.recorder").new_tour({ title = title })
    vim.notify(string.format("CodeTour: 已创建 %s\nprojectRoot=%s", tour._path, tour.projectRoot))
  end, { nargs = "?", desc = "新建 tour（projectRoot 自动取自当前 cwd）" })

  cmd("CodeTourAddStep", function()
    local title = vim.fn.input("Marker (函数名等，可留空): ")
    local desc = vim.fn.input("Description: ")
    local ok, result = pcall(require("codetour.recorder").add_step, {
      title = title ~= "" and title or nil,
      description = desc,
    })
    if not ok then
      vim.notify("CodeTour: 添加 step 失败：" .. tostring(result), vim.log.levels.ERROR)
      return
    end
    vim.notify(string.format(
      "CodeTour: step 已追加 [%s] %s:%d",
      result.title or "",
      vim.fs.basename(result.file),
      result.line
    ))
  end, { desc = "把当前光标位置作为 step 加入正在录制的 tour（prompt: marker + description）" })

  cmd("CodeTourOpenDir", function()
    local dir = require("codetour").config.tours_dir
    vim.fn.mkdir(dir, "p")
    vim.cmd("edit " .. vim.fn.fnameescape(dir))
  end, { desc = "打开 tours 目录（用于跨设备迁移时手动改 projectRoot）" })

  cmd("CodeTourResume", function()
    require("codetour.picker").pick_tour_for_resume()
  end, { desc = "选一个已有 tour 激活，准备继续追加 step" })
end

return M
