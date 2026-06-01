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

-- Preserve register when pasting over a visual selection
-- Delete selection to the black hole register then put the default register
vim.keymap.set({ "v", "x" }, "p", '"_dP', { noremap = true, silent = true })
vim.keymap.set({ "v", "x" }, "P", '"_dP', { noremap = true, silent = true })

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

-- Add semicolon at end of line(s) without moving cursor
local function add_semicolon()
    local mode = vim.api.nvim_get_mode().mode

    if mode == "n" then
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        if not line:match(";%s*$") then
            vim.api.nvim_set_current_line(line .. ";")
        end
        vim.api.nvim_win_set_cursor(0, { row, col })
        return
    end

    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]

    for row = start_row, end_row do
        local line = vim.fn.getline(row)
        if not line:match(";%s*$") then
            vim.fn.setline(row, line .. ";")
        end
    end
end
vim.keymap.set("n", "<C-;>", add_semicolon, { noremap = true, silent = true })
vim.keymap.set("v", "<C-;>", add_semicolon, { noremap = true, silent = true })

local function add_comma()
    local mode = vim.api.nvim_get_mode().mode

    if mode == "n" then
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()

        if not line:match(",%s*$") then
            vim.api.nvim_set_current_line(line .. ",")
        end

        vim.api.nvim_win_set_cursor(0, { row, col })
        return
    end

    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]

    for row = start_row, end_row do
        local line = vim.fn.getline(row)
        if not line:match(",%s*$") then
            vim.fn.setline(row, line .. ",")
        end
    end
end

vim.keymap.set({ "n", "v" }, "<C-,>", add_comma, {
    noremap = true,
    silent = true,
    desc = "Add comma at end of line",
})

-- Telescope
vim.keymap.set("n", "<C-l>", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })

-- code action
vim.keymap.set("n", "<C-i>", vim.lsp.buf.code_action)

-- git
require('gitsigns').setup({
    on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Move between hunks
        map('n', '<C-j>', gs.next_hunk, 'Next Git Hunk')
        map('n', '<C-h>', gs.prev_hunk, 'Previous Git Hunk')
    end
})
