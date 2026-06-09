local oxlintConfigPath = vim.fn.stdpath("config") .. "/style/oxlint-nest-config.mjs"

return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- Custom oxlint linter configured with nest-oxlint-config
		lint.linters.oxlint_nest = {
			cmd = function()
				local local_binary = vim.fn.fnamemodify("./node_modules/.bin/oxlint", ":p")
				return vim.uv.fs_stat(local_binary) and local_binary or "oxlint"
			end,
			stdin = false,
			args = { "--format", "github", "--config", oxlintConfigPath },
			stream = "stdout",
			ignore_exitcode = true,
			parser = require("lint.parser").from_pattern(
				"::([^ ]+) file=(.*),line=(%d+),endLine=(%d+),col=(%d+),endColumn=(%d+),title=(.*)::(.*)",
				{ "severity", "file", "lnum", "end_lnum", "col", "end_col", "code", "message" },
				{ ["error"] = vim.diagnostic.severity.ERROR, ["warning"] = vim.diagnostic.severity.WARN },
				{ ["source"] = "oxlint" },
				{}
			),
		}

		lint.linters_by_ft = {
			javascript = { "oxlint_nest" },
			typescript = { "oxlint_nest" },
			javascriptreact = { "oxlint_nest" },
			typescriptreact = { "oxlint_nest" },
			python = { "pylint" },
		}

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
