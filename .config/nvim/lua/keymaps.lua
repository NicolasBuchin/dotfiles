-- File Tree Toggle
vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>")

-- File Finder with Telescope
vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>")

-- Comment/Uncomment
vim.keymap.set("n", "<C-k>", "gcc", { remap = true, silent = true })
vim.keymap.set("v", "<C-k>", "gc", { remap = true, silent = true })


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
vim.keymap.set({ "v", "x" }, "p", '"_dP', { noremap = true, silent = true })
vim.keymap.set({ "v", "x" }, "P", '"_dP', { noremap = true, silent = true })

-- Same for change (c)
vim.keymap.set("n", "c", '"_c', { noremap = true })
vim.keymap.set("v", "c", '"_c', { noremap = true })
vim.keymap.set("n", "C", '"_C', { noremap = true })
vim.keymap.set("v", "C", '"_C', { noremap = true })

-- Yank copies to system clipboard
vim.keymap.set("n", "y", '"+y', { noremap = true })
vim.keymap.set("v", "y", '"+y', { noremap = true })
vim.keymap.set("n", "Y", '"+Y', { noremap = true })

-- Append a character at the end of the line(s)
local function append_at_eol(char)
    local pattern = vim.pesc(char) .. "%s*$"

    local function append(row)
        local line = vim.fn.getline(row)
        if not line:match(pattern) then
            vim.fn.setline(row, line .. char)
        end
    end

    return function()
        if vim.api.nvim_get_mode().mode == "n" then
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            append(row)
            vim.api.nvim_win_set_cursor(0, { row, col })
            return
        end

        for row = vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2] do
            append(row)
        end
    end
end

vim.keymap.set({ "n", "v" }, "<C-;>", append_at_eol(";"),
    { noremap = true, silent = true, desc = "Add semicolon at end of line" })
vim.keymap.set({ "n", "v" }, "<C-,>", append_at_eol(","),
    { noremap = true, silent = true, desc = "Add comma at end of line" })

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


vim.keymap.set("n", "<C-S-a>", function()
    local gitsigns = require("gitsigns")
    gitsigns.stage_hunk()
end, { desc = "Stage/unstage Git hunk" })
