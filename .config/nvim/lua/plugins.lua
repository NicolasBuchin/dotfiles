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

-- Plugin Setup with Lazy.nvim
require("lazy").setup({
	-- UI / Theme
	{ "AlexvZyl/nordic.nvim", lazy = false, priority = 1000 },

	-- Syntax Highlighting
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

	-- File Explorer / Finder
	{ "nvim-tree/nvim-tree.lua" },
	{ "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },

	-- LSP / Completion
	{ "neovim/nvim-lspconfig", version = "v0.1.7" },

	{ "hrsh7th/nvim-cmp" },
	{ "hrsh7th/cmp-nvim-lsp" },
	{ "L3MON4D3/LuaSnip" },

	-- Rust Tools
	{ "simrat39/rust-tools.nvim" },

	-- Debugging / Linting / Formatting
	{ "mfussenegger/nvim-dap" },
	{ "dense-analysis/ale" },

	-- Markdown Preview Plugin
	{
		"iamcco/markdown-preview.nvim",
		build = "cd app && npm install",
		ft = "markdown",
		config = function()
			vim.g.mkdp_auto_start = 1 -- auto start preview when editing Markdown files
			-- You can add more configuration options here if desired.
		end,
	},

	-- Misc
	{ "numToStr/Comment.nvim" },
	{ "windwp/nvim-autopairs" },

	{
		"nvim-tree/nvim-web-devicons",
		lazy = true,
	},
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
})

-- auto start on opening Cargo.toml
vim.api.nvim_create_autocmd("BufRead", {
	pattern = "Cargo.toml",
	callback = function()
		require("crates").show()
	end,
})

-- Theme Setup
require("nordic").setup({
	transparent = {
		bg = true,
		float = true,
	},
	cursorline = { theme = "light" },
	telescope = { style = "classic" },
	on_palette = function(palette)
		palette.gray4 = "#8D9096"
		palette.green.base = palette.cyan.base
	end,
	on_highlight = function(highlights, _palette)
		for _, highlight in pairs(highlights) do
			highlight.bold = false
		end
	end,
})
vim.cmd([[colorscheme nordic]])
vim.cmd([[
  hi Normal guibg=NONE ctermbg=NONE
  hi NormalNC guibg=NONE ctermbg=NONE
  hi SignColumn guibg=NONE ctermbg=NONE
  hi NormalFloat guibg=NONE ctermbg=NONE
  hi FloatBorder guibg=NONE ctermbg=NONE
]])

-- Treesitter Configuration
require("nvim-treesitter.configs").setup({
	ensure_installed = { "lua", "python", "javascript", "rust", "c", "cpp" },
	sync_install = false,
	ignore_install = {},
	auto_install = true,
	highlight = {
		enable = true,
	},
	modules = {},
})

-- Telescope Setup
require("telescope").setup({})

-- Comment.nvim Setup
require("Comment").setup({})

-- Nvim-Tree Setup with matching background
require("nvim-tree").setup()
vim.cmd([[
  hi NvimTreeNormal guibg=NONE ctermbg=NONE
  hi NvimTreeEndOfBuffer guibg=NONE ctermbg=NONE
  hi NvimTreeVertSplit guibg=NONE ctermbg=NONE
  hi NvimTreeStatusLine guibg=NONE ctermbg=NONE
  hi NvimTreeNormalNC guibg=NONE ctermbg=NONE
]])

-- Gitsigns Setup
require("gitsigns").setup({
	signs = {
		add = { text = "+" },
		change = { text = "~" },
		delete = { text = "-" },
		topdelete = { text = "-" },
		changedelete = { text = "~" },
	},
	signcolumn = true,
	numhl = false,
	linehl = false,
	word_diff = false,
	watch_gitdir = {
		interval = 1000,
		follow_files = true,
	},
	attach_to_untracked = true,
	current_line_blame = false,
	current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = "eol",
		delay = 500,
		ignore_whitespace = false,
	},
	update_debounce = 100,
	status_formatter = nil,
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns

		local function map(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		-- Navigation
		map("n", "]c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gs.nav_hunk("next")
			end
		end)

		map("n", "[c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gs.nav_hunk("prev")
			end
		end)

		-- Actions
		map("n", "gs", gs.stage_hunk)
		map("n", "gp", gs.preview_hunk)
		map("n", "gb", function()
			gs.blame_line({ full = true })
		end)
	end,
})

require("luasnip.loaders.from_vscode").lazy_load({
	paths = { vim.fn.stdpath("config") .. "/vscode-snippets" },
})

-- Customize nvim-web-devicons
local palette = require("nordic.colors")
local c_color = palette.blue0
local h_color = palette.blue1

require("nvim-web-devicons").set_icon({
	c = { icon = "", color = c_color, name = "C_alt" },
	cpp = { icon = "", color = c_color, name = "Cpp_alt" },
	h = { icon = "", color = h_color, name = "H_alt" },
	hpp = { icon = "", color = h_color, name = "Hpp_alt" },
})
