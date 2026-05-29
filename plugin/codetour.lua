if vim.g.loaded_codetour then
  return
end
vim.g.loaded_codetour = 1

require("codetour.commands").register()
