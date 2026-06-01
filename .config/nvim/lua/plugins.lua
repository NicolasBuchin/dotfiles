-- Lazy.nvim Bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- UI / Theme
    { "AlexvZyl/nordic.nvim",            lazy = false,                              priority = 1000 },

    -- Syntax Highlighting
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

    -- File Explorer / Finder
    { "nvim-tree/nvim-tree.lua" },
    { "nvim-telescope/telescope.nvim",   dependencies = { "nvim-lua/plenary.nvim" } },

    -- LSP / Completion
    { "neovim/nvim-lspconfig",           version = "v0.1.7" },

    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-buffer" },
    { "hrsh7th/cmp-path" },
    { "L3MON4D3/LuaSnip" },
    { "saadparwaiz1/cmp_luasnip" },

    -- Rust Tools
    { "simrat39/rust-tools.nvim" },

    -- Debugging / Linting / Formatting
    { "mfussenegger/nvim-dap" },
    { "dense-analysis/ale" },

    -- Misc
    { "numToStr/Comment.nvim" },
    { "windwp/nvim-autopairs" },

    { "nvim-tree/nvim-web-devicons" },
    {
        "saecki/crates.nvim",
        tag = "stable",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("crates").setup()
        end,
        ft = { "toml" },
    },

    { "lewis6991/gitsigns.nvim" },

    { "stevearc/conform.nvim" },
})
