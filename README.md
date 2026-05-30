# codetour.nvim

> 一个把 [VSCode CodeTour](https://github.com/microsoft/codetour) 体验搬到 Neovim 的代码导览插件。基于内置 quickfix 渲染步骤列表,跨设备同步、可视化编辑、支持 undo/redo。

[![Lua](https://img.shields.io/badge/Made%20with-Lua-blue.svg?style=flat-square)](https://www.lua.org/)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&logo=neovim)](https://neovim.io/)
[![Tests](https://img.shields.io/badge/tests-60%2F60-brightgreen?style=flat-square)](./tests)

## 它是什么

**Code Tour** 是一种把"项目内一组关键代码位置 + 解释文字"打包成可回放的"步骤序列"的工作流,适合 onboarding、code review、模块讲解、自己给未来的自己留路标。

`codetour.nvim` 在 Neovim 中重建了这种体验,并做了若干 VSCode 版没有的改进:

- **不依赖浮窗**:用内置 quickfix 渲染步骤树,自带 `<CR>` 跳转、`:cnext`/`:cprev` 导航
- **集中式存储**:所有 `.tour` 文件统一放在 `stdpath('data')/codetour/tours/`,跨设备同步只需把这个目录挂到云盘
- **就地编辑**:quickfix 里直接用 Shift+方向键调顺序/depth,`u`/`<C-r>` 撤销重做
- **JSON 兼容**:`.tour` 文件格式与 VSCode 版完全兼容,可双向使用

---

## 截图

```
    0   1   2                       S-↑/S-↓ move  S-←/S-→ depth  dd del  u/C-r undo  e edit
my-tour
├── setup           init.lua:42       初始化入口,注册 autocmd
│   ├── parse_opts  init.lua:88       合并用户配置
│   ├── apply_hl    init.lua:120      装载高亮组
├── runner          runner.lua:1      渲染逻辑
│   ├── populate    runner.lua:73     把 tour 转 qf items
└── teardown        init.lua:158      关闭时清理
```

---

## 功能

- [x] 选择并开始一个 tour,用 quickfix 树形渲染所有步骤
- [x] 步骤回放:`<CR>` 跳代码、`:cn`/`:cp` 上下导航、`:cc N` 跳第 N 步
- [x] 树形缩进显示(`depth` 字段),CJK 宽度对齐
- [x] 创建/录制 tour:`:CodeTourNew` + `:CodeTourAddStep`,把光标处包装为 step
- [x] quickfix 内编辑步骤:
  - **Shift+↑/↓** 上移/下移
  - **Shift+←/→** outdent/indent (调整 depth)
  - **dd** 删除步骤
  - **u** / **<C-r>** 撤销/重做(最多 100 步)
  - **e** 用主窗口打开 `.tour` JSON 文件原地编辑,保存后自动重渲染
- [x] tour 文件外部修改自动监听(`BufWritePost` reload + refresh quickfix)
- [x] 跨设备迁移:`projectRoot` 字段记录绝对路径,目录可同步,迁移时改一行即可
- [x] 与 [snacks.picker](https://github.com/folke/snacks.nvim) 集成(可选,无则回退到 `vim.ui.select`)
- [x] 高亮组全部 `default link`,可被用户主题覆盖
- [x] `quickfixtextfunc` 自动判断仅对 CodeTour 标题前缀的 list 生效,不污染其他 quickfix 使用场景
- [x] 60 个 spec 全绿,覆盖 loader / state / recorder / runner / editor 全模块

---

## 安装

### lazy.nvim

```lua
{
  "yintao/codetour.nvim",
  cmd = {
    "CodeTourStart", "CodeTourEnd", "CodeTourNew",
    "CodeTourAddStep", "CodeTourOpenDir", "CodeTourResume",
  },
  keys = {
    { "<leader>ct", "<cmd>CodeTourStart<cr>",   desc = "CodeTour: start" },
    { "<leader>ce", "<cmd>CodeTourEnd<cr>",     desc = "CodeTour: end" },
    { "<leader>cN", "<cmd>CodeTourNew<cr>",     desc = "CodeTour: new tour" },
    { "<leader>cA", "<cmd>CodeTourAddStep<cr>", desc = "CodeTour: add step" },
    { "<leader>cO", "<cmd>CodeTourOpenDir<cr>", desc = "CodeTour: open tours dir" },
    { "<leader>cR", "<cmd>CodeTourResume<cr>",  desc = "CodeTour: resume for recording" },
  },
  opts = {},
}
```

### packer.nvim

```lua
use {
  "yintao/codetour.nvim",
  config = function() require("codetour").setup() end,
}
```

### 要求

- Neovim **>= 0.10**(用到了 `vim.uv`、`vim.fs`、`virt_text_pos = "right_align"`)
- 可选:[snacks.nvim](https://github.com/folke/snacks.nvim) 的 picker 模块(更好的 tour 选择体验)
- 终端支持 Shift+方向键(iTerm2 / WezTerm / Kitty / Ghostty / Alacritty / 现代 GUI Neovim 均默认支持)

---

## 配置

`setup()` 全部参数均可省略,以下是默认值:

```lua
require("codetour").setup({
  -- .tour 文件存放目录;迁移到云盘只需改这里
  tours_dir = vim.fn.stdpath("data") .. "/codetour/tours",

  -- quickfix buffer-local 键位;赋空字符串 "" 即不绑定
  qf_keymaps = {
    move_up   = "<S-Up>",
    move_down = "<S-Down>",
    outdent   = "<S-Left>",
    indent    = "<S-Right>",
    delete    = "dd",
    undo      = "u",
    redo      = "<C-r>",
    edit_tour = "e",
  },
})
```

### 跨设备同步示例

```lua
require("codetour").setup({
  tours_dir = vim.fn.expand("~/Dropbox/codetour-tours"),
})
```

每个 `.tour` 自带 `projectRoot` 字段,迁移到新机器后如果项目路径变了,用 `:CodeTourOpenDir` 编辑对应 `.tour` 的 `projectRoot` 即可(也支持 `~` 前缀)。

---

## 命令

| 命令 | 默认键 | 说明 |
|---|---|---|
| `:CodeTourStart` | `<leader>ct` | picker 选 tour → 打开 quickfix + 跳第 1 步 |
| `:CodeTourEnd` | `<leader>ce` | 关闭 quickfix + 清空 active tour state |
| `:CodeTourNew [title]` | `<leader>cN` | 新建 tour(自动激活并打开 quickfix,焦点保留在原窗口) |
| `:CodeTourAddStep [depth]` | `<leader>cA` | 当前光标位置追加 step(prompt marker + description) |
| `:CodeTourResume` | `<leader>cR` | picker 选已有 tour 仅激活,准备继续追加 |
| `:CodeTourOpenDir` | `<leader>cO` | 打开 tours 目录(用于跨设备迁移时编辑 projectRoot) |

---

## quickfix 内键位

仅在 CodeTour 创建的 quickfix list 上生效(通过 `getqflist({title=1})` 前缀判断),不影响其他 quickfix 使用场景。键位均为 buffer-local + `nowait`,优先级高于 global mapping。

| 键 | 行为 |
|---|---|
| `<S-Up>` | 把当前 step 上移一位(顺序交换,depth 跟随) |
| `<S-Down>` | 下移一位 |
| `<S-Left>` | depth -1(下限 0) |
| `<S-Right>` | depth +1(无上限) |
| `dd` | 删除当前 step |
| `u` | 撤销最近一次编辑,光标回到操作前位置 |
| `<C-r>` | 重做 |
| `e` | 在主窗口打开 `.tour` JSON 文件直接编辑 |
| `<CR>` | (vim 默认)跳到 step 对应的 file:line |
| `:cn` / `:cp` | (vim 默认)下一步 / 上一步 |

> 撤销栈仅保存在内存中,关闭 tour 后清空。新动作会清空 redo 栈。

ruler 行右侧会用灰色 virtual text 实时显示当前键位映射,改 `qf_keymaps` 提示也会跟着变。

---

## .tour 文件格式

完全兼容 VSCode CodeTour 的 JSON Schema,额外增加 `projectRoot` 字段用于跨设备:

```json
{
  "$schema": "https://aka.ms/codetour-schema",
  "title": "Onboarding",
  "description": "从 main 入口讲起",
  "projectRoot": "~/projects/codetour.nvim",
  "ref": "main",
  "steps": [
    {
      "file": "lua/codetour/init.lua",
      "line": 1,
      "title": "Entry",
      "description": "模块入口",
      "depth": 0
    },
    {
      "file": "lua/codetour/runner.lua",
      "line": 73,
      "title": "populate",
      "description": "把 tour 转 quickfix items",
      "depth": 1
    },
    {
      "contents": "纯文字步骤,无需绑定文件",
      "description": "里程碑"
    },
    {
      "directory": "lua/codetour",
      "description": "整个源码目录"
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `title` | string | ✓ | tour 标题,显示在 picker 和 quickfix header |
| `description` | string |   | tour 整体描述 |
| `projectRoot` | string | ✓ | 项目绝对路径,支持 `~`,迁移机器时修改这里 |
| `ref` | string |   | git ref(VSCode 字段,本插件目前仅保留) |
| `steps` | array | ✓ | 步骤序列,每个 step 至少包含 `file+line` 或 `contents` 或 `directory` |
| `steps[].file` | string |   | 相对 projectRoot 的文件路径 |
| `steps[].line` | number |   | 1-based 行号 |
| `steps[].title` | string |   | 树形 marker 显示文本(函数名等) |
| `steps[].description` | string |   | step 解释 |
| `steps[].depth` | number |   | 缩进层级,默认 0;无上限;影响 quickfix 树形渲染 |
| `steps[].directory` | string |   | 目录类 step(替代 file) |
| `steps[].contents` | string |   | 纯文字 step(无跳转) |

---

## 工作流

### 录制一个 tour

```vim
:CodeTourNew Onboarding   " 输入 title,quickfix 自动打开
" 焦点保留在原窗口,光标定位到第一个想讲的代码行
:CodeTourAddStep          " 输入 marker (可空) + description
" 切到下一段代码,继续 cA
:CodeTourAddStep 1        " 加一个 depth=1 的子步骤
" 编辑完了用 quickfix 内的 S-↑/S-↓/S-←/S-→ 微调结构
```

### 播放一个 tour

```vim
:CodeTourStart            " picker 选,自动跳第 1 步
:cn / :cp                 " 上下切步,代码窗口自动跟随
<CR>                      " 在 quickfix 上点回车跳转
:CodeTourEnd              " 收工
```

### 代码漂移时修正

当源码被重构,行号过时时:

1. quickfix 内按 `e` 打开 `.tour` JSON
2. 直接改 `"line": 42` 数字,或者用 `:%s` 批量改路径
3. `:w` 保存 → quickfix 立即重新渲染

也可以用 `:CodeTourOpenDir` 直接进文件浏览,选 tour 编辑。

### 继续往老 tour 里加步骤

```vim
:CodeTourResume           " picker 选 tour,仅激活不显示
:CodeTourAddStep
```

---

## 高亮组

全部 `default link`,被你的 colorscheme 覆盖时自动应用主题色:

| 高亮组 | 默认 link | 用途 |
|---|---|---|
| `CodeTourRuler` | `Comment` | quickfix 顶部 `0 1 2 3` 标尺 |
| `CodeTourTree` | `Normal` | 树形前缀 `├── │   ` 和 marker |
| `CodeTourDesc` | `Comment` | step description 文字 |
| `CodeTourHint` | `Comment` | ruler 行右侧的快捷键提示 |

自定义示例:

```lua
vim.api.nvim_set_hl(0, "CodeTourRuler", { fg = "#5c6370", bold = true })
vim.api.nvim_set_hl(0, "CodeTourTree",  { fg = "#abb2bf" })
vim.api.nvim_set_hl(0, "CodeTourDesc",  { fg = "#7f848e", italic = true })
vim.api.nvim_set_hl(0, "CodeTourHint",  { fg = "#3e4452" })
```

---

## API

如果你想自己接入,以下是公开接口:

```lua
local codetour = require("codetour")
codetour.setup(opts)                  -- 见上文配置
codetour.pick()                       -- 打开 tour picker
codetour.start(tour_table)            -- 直接用 tour 数据开始
codetour.end_tour()                   -- 退出当前 tour
codetour.format_qf_hint()             -- 拿到当前键位提示字符串

local loader = require("codetour.loader")
loader.discover(tours_dir)            -- 返回所有 .tour 路径
loader.load(path)                     -- 解析单个 tour
loader.save(tour)                     -- 写回(自动过滤 `_` 开头字段)

local state = require("codetour.state")
state.active_tour()                   -- 当前 active tour
state.active_step()                   -- 当前 step 对象
state.on("step_changed", function(idx) ... end)

local recorder = require("codetour.recorder")
recorder.new_tour({ title = "T" })    -- 新建 + 激活
recorder.add_step({ description = "...", title = "marker", depth = 1 })
```

---

## 测试

```bash
cd codetour.nvim
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

需要 [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) 已安装。

---

## 与 VSCode CodeTour 的差异

| 特性 | VSCode CodeTour | codetour.nvim |
|---|---|---|
| `.tour` JSON 格式 | ✓ | ✓(完全兼容) |
| 步骤跳转 | tree view 点击 | quickfix `<CR>` / `:cn` / `:cp` |
| 步骤展示 | 侧栏树 + 浮窗 | quickfix 树形渲染 |
| 录制 | UI 录制 | 命令式 `:CodeTourAddStep` |
| 跨项目 / 跨设备 | 文件随项目走 | 集中目录 + projectRoot 字段 |
| 步骤编辑 | UI 拖拽 | quickfix Shift+方向键 / `e` 编辑 JSON |
| 撤销 | ✗ | u / `<C-r>` |
| pattern 锚定 | ✓(自动适应代码漂移) | ✗(计划中) |
| 浏览器内嵌 web preview | ✓ | ✗ |
| 多语言命令链接 | ✓ | ✗ |

---

## Roadmap

- [ ] step 的 `pattern` 字段(用代码片段定位而非死行号,自动适应漂移)
- [ ] 录制时弹 markdown buffer 编辑多行描述
- [ ] step 的 `commands` 数组(VSCode 命令到 nvim 命令映射)
- [ ] tour 级 `nextTour` 链式跳转
- [ ] picker 按 `projectRoot` 分组聚合
- [ ] tours_dir 递归扫描子目录
- [ ] 与 neo-tree / gitsigns 联动

---

## 致谢

- [VSCode CodeTour](https://github.com/microsoft/codetour) — 灵感来源与 JSON Schema
- [snacks.nvim](https://github.com/folke/snacks.nvim) — picker 后端
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) — 测试框架

---

## License

MIT
