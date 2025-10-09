-- File Tree Toggle
vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>")

-- File Finder with Telescope
vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>")

-- Comment/Uncomment
vim.keymap.set("n", "<C-k>", ":lua require('Comment.api').toggle.linewise.current()<CR>")
vim.keymap.set("v", "<C-k>", ":lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", { silent = true })

-- Indentation (Normal Mode)
vim.keymap.set("n", "<C-Tab>", ">>", { noremap = true, silent = true, desc = "Indent line" })
vim.keymap.set("n", "<S-Tab>", "<<", { noremap = true, silent = true, desc = "Unindent line" })

-- Indentation (Visual Mode)
vim.keymap.set("v", "<C-Tab>", ">gv", { noremap = true, silent = true, desc = "Indent selection" })
vim.keymap.set("v", "<S-Tab>", "<gv", { noremap = true, silent = true, desc = "Unindent selection" })

-- Disable middle mouse paste in normal, visual, and insert modes
vim.keymap.set("n", "<MiddleMouse>", "<Nop>")
vim.keymap.set("v", "<MiddleMouse>", "<Nop>")
vim.keymap.set("i", "<MiddleMouse>", "<Nop>")

-- Prevent deletes from overwriting the clipboard
vim.keymap.set("n", "d", '"_d', { noremap = true })
vim.keymap.set("v", "d", '"_d', { noremap = true })
vim.keymap.set("n", "D", '"_D', { noremap = true })
vim.keymap.set("v", "D", '"_D', { noremap = true })

-- Same for change (c)
vim.keymap.set("n", "c", '"_c', { noremap = true })
vim.keymap.set("v", "c", '"_c', { noremap = true })
vim.keymap.set("n", "C", '"_C', { noremap = true })
vim.keymap.set("v", "C", '"_C', { noremap = true })

-- x and X already covered in your config:
-- vim.keymap.set("n", "x", '"_x', { noremap = true })
-- vim.keymap.set("n", "X", '"_X', { noremap = true })

-- Yank still copies to system clipboard
vim.keymap.set("n", "y", '"+y', { noremap = true })
vim.keymap.set("v", "y", '"+y', { noremap = true })
vim.keymap.set("n", "Y", '"+Y', { noremap = true })
