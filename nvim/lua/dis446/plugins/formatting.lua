local oxfmtConfigPath = "/home/ubby/Code/alpha/back-end/nest-common/packages/nest-oxfmt-config/index.mjs"

return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")

		-- Custom oxfmt formatter configured with nest-oxfmt-config
		conform.formatters.oxfmt_nest = {
			command = require("conform.util").from_node_modules("oxfmt"),
			args = function(_, ctx)
				return { "--stdin-filepath", ctx.filename, "--config", oxfmtConfigPath }
			end,
			stdin = true,
		}

		conform.setup({
			formatters_by_ft = {
				javascript = { "oxfmt_nest" },
				typescript = { "oxfmt_nest" },
				javascriptreact = { "oxfmt_nest" },
				typescriptreact = { "oxfmt_nest" },
				css = { "prettier" },
				html = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				markdown = { "prettier" },
				graphql = { "prettier" },
				liquid = { "prettier" },
				lua = { "stylua" },
				python = { "isort", "black" },
			},
			format_on_save = {
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			})
		end, { desc = "Format file or range (in visual mode)" })
	end,
}
