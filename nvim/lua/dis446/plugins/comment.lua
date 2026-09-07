return {
	-- engine: commenting (replaced numToStr/Comment.nvim, unmaintained since
	-- 2024 and broken on nvim 0.12's lazy tree parsing). Same gcc/gc keys,
	-- dot-repeat, v:count. Language support: every ftplugin 'commentstring'
	-- plus local treesitter inference. No gb/gbc blockwise (per-line only).
	"nvim-mini/mini.comment",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		-- for jsx/tsx/html context commentstrings (used via custom_commentstring)
		"JoosepAlviste/nvim-ts-context-commentstring",
	},
	opts = {
		options = {
			custom_commentstring = function()
				local ok, cs = pcall(require("ts_context_commentstring").calculate_commentstring, {
					key = vim.api.nvim_get_mode().mode == "v" and "__multiline" or "__default",
				})
				return (ok and cs) or vim.bo.commentstring
			end,
		},
	},
}
