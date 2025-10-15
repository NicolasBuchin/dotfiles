-- Load and setup Nordic theme
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

-- Apply the colorscheme to ensure highlights are loaded
vim.cmd("colorscheme nordic")

-- Load nvim-web-devicons
local ok, devicons = pcall(require, "nvim-web-devicons")
if not ok then
	print("Error: nvim-web-devicons not found!")
	return
end

-- Helper function to get highlight color
local function get_hl_color(hl_name)
	local hl = vim.api.nvim_get_hl(0, { name = hl_name })
	if hl.fg then
		return string.format("#%06x", hl.fg)
	end
	return nil
end

-- Helper function to get icon color from devicons
local function get_icon_color(icon_data)
	if icon_data.color then
		return icon_data.color
	end
	if icon_data.cterm_color then
		-- Fallback to cterm color if available
		return icon_data.cterm_color
	end
	return nil
end

-- Get all icons and their colors
local icons_by_filename = devicons.get_icons_by_filename()
local icons_by_extension = devicons.get_icons_by_extension()

-- Get directory icon
local dir_icon, dir_color = devicons.get_icon("folder", "", { default = true })
if not dir_color then
	dir_color = get_hl_color("Directory") or "#5E81AC"
end

-- Build extension mappings
local extensions = {}
for ext, icon_data in pairs(icons_by_extension) do
	local color = get_icon_color(icon_data) or "#D8DEE9"
	local glyph = icon_data.icon or ""

	extensions[ext] = {
		filename = { foreground = color },
		icon = { glyph = glyph },
	}
end

-- Build filename mappings
local filenames = {}
for filename, icon_data in pairs(icons_by_filename) do
	local glyph = icon_data.icon or ""

	filenames[filename] = {
		icon = { glyph = glyph },
	}
end

-- Get common highlight colors from Nordic theme
local git_add = get_hl_color("GitSignsAdd") or get_hl_color("DiffAdd") or "#A3BE8C"
local git_change = get_hl_color("GitSignsChange") or get_hl_color("DiffChange") or "#EBCB8B"
local git_delete = get_hl_color("GitSignsDelete") or get_hl_color("DiffDelete") or "#BF616A"
local comment_color = get_hl_color("Comment") or "#616E88"
local warning_color = get_hl_color("WarningMsg") or "#EBCB8B"
local error_color = get_hl_color("ErrorMsg") or "#BF616A"
local symlink_color = get_hl_color("Title") or "#88C0D0"
local normal_color = get_hl_color("Normal") or "#D8DEE9"

-- Build the theme structure
local theme = {
	colourful = true,
	filekinds = {
		normal = { foreground = normal_color },
		directory = { foreground = dir_color },
		symlink = { foreground = symlink_color },
	},
	links = {
		normal = { foreground = symlink_color },
		multi_link_file = { foreground = symlink_color },
	},
	git = {
		new = { foreground = git_add },
		modified = { foreground = git_change },
		deleted = { foreground = git_delete },
		renamed = { foreground = warning_color },
		typechange = { foreground = warning_color },
		ignored = { foreground = comment_color },
		conflicted = { foreground = error_color },
	},
	git_repo = {
		branch_main = { foreground = git_add },
		branch_other = { foreground = warning_color },
		git_clean = { foreground = git_add },
		git_dirty = { foreground = git_change },
	},
	file_type = {
		image = { foreground = extensions.png and extensions.png.filename.foreground or "#B48EAD" },
		video = { foreground = extensions.mp4 and extensions.mp4.filename.foreground or "#B48EAD" },
		music = { foreground = extensions.mp3 and extensions.mp3.filename.foreground or "#A3BE8C" },
		lossless = { foreground = extensions.flac and extensions.flac.filename.foreground or "#A3BE8C" },
		crypto = { foreground = extensions.asc and extensions.asc.filename.foreground or "#EBCB8B" },
		document = { foreground = extensions.pdf and extensions.pdf.filename.foreground or "#81A1C1" },
		compressed = { foreground = extensions.zip and extensions.zip.filename.foreground or "#BF616A" },
		temp = { foreground = comment_color },
		compiled = { foreground = extensions.o and extensions.o.filename.foreground or "#616E88" },
		build = { foreground = extensions.mk and extensions.mk.filename.foreground or "#EBCB8B" },
		source = { foreground = normal_color },
	},
	filenames = filenames,
	extensions = extensions,
}

-- YAML serialization function
local function serialize_value(value, indent)
	indent = indent or 0
	local prefix = string.rep("  ", indent)

	if type(value) == "string" then
		-- Quote strings that contain special characters or look like numbers/booleans
		if
			value:match("^[%d#]")
			or value:match("[:%{%}%[%]]")
			or value == "true"
			or value == "false"
			or value == "yes"
			or value == "no"
		then
			return string.format('"%s"', value)
		end
		return value
	elseif type(value) == "number" then
		return tostring(value)
	elseif type(value) == "boolean" then
		return value and "true" or "false"
	elseif type(value) == "table" then
		local lines = {}
		-- Check if it's an array
		local is_array = #value > 0
		if is_array then
			for _, v in ipairs(value) do
				table.insert(lines, prefix .. "- " .. serialize_value(v, indent + 1))
			end
		else
			for k, v in pairs(value) do
				if type(v) == "table" then
					table.insert(lines, prefix .. k .. ":")
					table.insert(lines, serialize_value(v, indent + 1))
				else
					table.insert(lines, prefix .. k .. ": " .. serialize_value(v, indent))
				end
			end
		end
		return table.concat(lines, "\n")
	end
	return ""
end

-- Generate YAML content
local yaml_lines = {}
for key, value in pairs(theme) do
	if type(value) == "table" then
		table.insert(yaml_lines, key .. ":")
		table.insert(yaml_lines, serialize_value(value, 1))
	else
		table.insert(yaml_lines, key .. ": " .. serialize_value(value, 0))
	end
end

local yaml_content = table.concat(yaml_lines, "\n")

-- Write to file
local output_file = "theme.yml"
local file = io.open(output_file, "w")
if file then
	file:write(yaml_content)
	file:close()
	print("Successfully generated " .. output_file)
	print("Total extensions mapped: " .. vim.tbl_count(extensions))
	print("Total filenames mapped: " .. vim.tbl_count(filenames))
else
	print("Error: Could not write to " .. output_file)
end
