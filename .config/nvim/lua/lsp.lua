local lsp = require("lspconfig")

-- Python
lsp.pyright.setup({
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				extraPaths = { "/home/nico/git/strobealign/src/python" },
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
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = {
        globals = { "vim", "love" }, 
      },
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

-- ALE Setup (Linting/Formatting)
vim.g.ale_fixers = {
	python = { "autopep8" },
	rust = { "rustfmt" },
	-- c = { "clang-format" },
	-- cpp = { "clang-format" },
	lua = { "stylua" },
}

vim.g.ale_linters = {
	python = { "flake8" },
	rust = { "cargo" },
	c = { "clang" },
	cpp = { "clang" },
}
vim.g.ale_fix_on_save = 1

-- nvim-autopairs Setup
require("nvim-autopairs").setup({
	check_ts = true,
})

-- Autopairs Integration with nvim-cmp
local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},
	mapping = {
		["<C-n>"] = cmp.mapping.select_next_item(),
		["<C-p>"] = cmp.mapping.select_prev_item(),
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
	},
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "buffer" },
	}),
})
cmp.event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())

-- LuaSnip Lazy Load VSCode-Style Snippets
require("luasnip.loaders.from_vscode").lazy_load()
