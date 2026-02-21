local lsp = require("lspconfig")
local cmp_nvim_lsp = require("cmp_nvim_lsp")
local capabilities = cmp_nvim_lsp.default_capabilities()

-- Python
lsp.pyright.setup({
    capabilities = capabilities,
    settings = {
        python = {
            analysis = {
                autoSearchPaths = true,
            },
        },
    },
})

-- Diagnostics
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

-- C / C++
lsp.clangd.setup({
    capabilities = capabilities,
    cmd = { "clangd", "--compile-commands-dir=build" },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_dir = lsp.util.root_pattern("compile_commands.json", ".git"),
})

-- Lua
lsp.lua_ls.setup({
    capabilities = capabilities,
    settings = {
        Lua = {
            format = {
                enable = true,
                defaultConfig = {
                    indent_style = "space",
                    indent_size = "4",
                },
            },
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
                checkThirdParty = false,
            },
            telemetry = { enable = false },
        },
    },
})

-- Rust
require("rust-tools").setup({
    server = {
        on_attach = function(_, bufnr)
            local rt = require("rust-tools")
            vim.keymap.set("n", "<S-t>", rt.hover_actions.hover_actions, { buffer = bufnr })
        end,
        settings = {
            ["rust-analyzer"] = {
                cargo = { allFeatures = true },
                diagnostics = { enable = true },
                checkOnSave = { command = "clippy" },
                inlayHints = {
                    typeHints = { enable = false },
                    parameterHints = { enable = false },
                    chainingHints = { enable = false },
                },
            },
        },
    },
})

-- ALE Linters
vim.g.ale_linters = {
    python = { "flake8" },
    rust = { "cargo" },
    c = { "clang" },
    cpp = { "clang" },
}

-- Format on Save
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.rs",
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.lua",
    callback = function()
        vim.lsp.buf.format({ async = false })
    end,
})
