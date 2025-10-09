-- UI Settings
vim.opt.number = true -- Show line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.termguicolors = true -- Enable 24-bit RGB colors
vim.cmd([[hi Normal guibg=NONE ctermbg=NONE]]) -- Transparent background

-- Tab/Indentation Settings (4 spaces)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- Use system clipboard as the default register
vim.opt.clipboard = "unnamedplus"
