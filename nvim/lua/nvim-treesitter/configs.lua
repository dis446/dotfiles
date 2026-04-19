local config = require("nvim-treesitter.config")

local M = {}

function M.setup(opts)
	return config.setup(opts)
end

function M.is_enabled(module_name, lang, bufnr)
	if module_name ~= "highlight" then
		return true
	end

	local ok = pcall(vim.treesitter.get_parser, bufnr, lang)
	return ok
end

function M.get_module(module_name)
	if module_name == "highlight" then
		return {
			additional_vim_regex_highlighting = false,
		}
	end

	return {}
end

return M
