return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"saghen/blink.cmp",
		-- "nvim-java/nvim-java",
	},
	config = function()
		local keymap = vim.keymap
		local border = "rounded"

		vim.diagnostic.config({
			severity_sort = true,
			update_in_insert = false,
			virtual_text = {
				spacing = 4,
				prefix = "●",
			},
			float = {
				border = border,
				source = "if_many",
			},
		})

		vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border })
		vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local opts = { buffer = ev.buf, silent = true }
				local client = vim.lsp.get_client_by_id(ev.data.client_id)

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", "<cmd>LspRestart<CR>", opts)

				if vim.lsp.inlay_hint and client and client.server_capabilities.inlayHintProvider then
					opts.desc = "Toggle inlay hints"
					keymap.set("n", "<leader>th", function()
						local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
						vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
					end, opts)
				end

				if client and client.server_capabilities.documentHighlightProvider then
					local highlight_augroup = vim.api.nvim_create_augroup("UserLspDocumentHighlight" .. ev.buf, {
						clear = true,
					})

					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						group = highlight_augroup,
						buffer = ev.buf,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						group = highlight_augroup,
						buffer = ev.buf,
						callback = vim.lsp.buf.clear_references,
					})
				end
			end,
		})

		local capabilities = require("blink.cmp").get_lsp_capabilities()

		local signs = { Error = "⛔", Warn = "⚠︎", Hint = "?", Info = "!" }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		local servers = {
			ts_ls = {},
			html = {},
			cssls = {},
			tailwindcss = {},
			graphql = {
				filetypes = { "graphql", "gql", "typescriptreact", "javascriptreact" },
			},
			emmet_ls = {
				filetypes = {
					"html",
					"typescriptreact",
					"javascriptreact",
					"css",
					"sass",
					"scss",
					"less",
				},
			},
			prismals = {},
			pyright = {},
			jsonls = {},
			yamlls = {},
			bashls = {},
			dockerls = {},
			sqls = {},
			marksman = {},
			lua_ls = {
				settings = {
					Lua = {
						runtime = {
							version = "LuaJIT",
						},
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							checkThirdParty = false,
						},
						telemetry = {
							enable = false,
						},
						completion = {
							callSnippet = "Replace",
						},
					},
				},
			},
		}

		for server_name, server_opts in pairs(servers) do
			vim.lsp.config(server_name, vim.tbl_deep_extend("force", {
				capabilities = capabilities,
			}, server_opts))
			vim.lsp.enable(server_name)
		end
	end,
}
