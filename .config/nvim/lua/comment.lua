-- Setup for Comment.nvim plugin with custom keybindings
require("Comment").setup({
  padding = true, -- Adds a space between comment and line
  sticky = true,  -- Cursor stays in place after commenting
  mappings = {
    basic = true,
    extra = true,
  },
  toggler = {
    line = '<C-k>',   -- Toggle comment on current line
  },
  opleader = {
    line = '<C-k>',   -- Toggle comment in visual mode
  },
})

