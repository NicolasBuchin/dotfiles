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

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

lsp.clangd.setup({
    capabilities = capabilities,
    cmd = { "clangd", "--compile-commands-dir=build" },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_dir = lsp.util.root_pattern("compile_commands.json", ".git"),
})

local function make_lua_library_with_love()
    local runtime_files = vim.api.nvim_get_runtime_file("", true) or {}

    local love_api_path = vim.fn.stdpath("data") .. "/love-api"

    local library = {}
    for _, p in ipairs(runtime_files) do
        library[p] = true
    end
    if vim.fn.isdirectory(love_api_path) == 1 then
        library[love_api_path] = true
    else
        library[love_api_path] = true
    end

    return library
end

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
            diagnostics = { globals = { "vim", "love" } },
            workspace = {
                library = make_lua_library_with_love(),
                checkThirdParty = false,
            },
            telemetry = { enable = false },
        },
    },
})

-- Rust LSP Setup via rust-tools
require("rust-tools").setup({
    server = {
        on_attach = function(_, bufnr)
            local cmp = require("cmp")
            cmp.setup.buffer({
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                }),
            })

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

vim.g.ale_linters = {
    python = { "flake8" },
    rust = { "cargo" },
    c = { "clang" },
    cpp = { "clang" },
}

-- nvim-autopairs Setup
require("nvim-autopairs").setup({
    check_ts = true,
})

-- Autopairs Integration with nvim-cmp
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
    experimental = {
        ghost_text = true, -- <<< THIS enables inline gray suggestion
    },

    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },

    mapping = cmp.mapping.preset.insert({
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),

        ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end, { "i", "s" }),

        ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, { "i", "s" }),
    }),

    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
    }),
})
cmp.event:on(
    "confirm_done",
    require("nvim-autopairs.completion.cmp").on_confirm_done()
)

-- LuaSnip Lazy Load VSCode-Style Snippets
require("luasnip.loaders.from_vscode").lazy_load()
