require("conform").setup({
    formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
    },
    format_on_save = {
        timeout_ms = 500,
        lsp_fallback = false,
    },
})
