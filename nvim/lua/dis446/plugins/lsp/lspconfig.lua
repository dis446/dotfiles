return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		-- "nvim-java/nvim-java",
	},
	config = function()
		local lspconfig = require("lspconfig")
		local mason_lspconfig = require("mason-lspconfig")
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

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

				opts.desc = "Show LSP references"
				keymap.set("n", "gR", function()
					Snacks.picker.lsp_references()
				end, opts)

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

				opts.desc = "Show LSP definitions"
				keymap.set("n", "gd", function()
					Snacks.picker.lsp_definitions()
				end, opts)

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", function()
					Snacks.picker.lsp_implementations()
				end, opts)

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", function()
					Snacks.picker.lsp_type_definitions()
				end, opts)

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", function()
					Snacks.picker.diagnostics_buffer()
				end, opts)

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

				opts.desc = "Go to previous diagnostic"
				keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)

				opts.desc = "Go to next diagnostic"
				keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

				opts.desc = "Show documentation for what is under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts)

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

		local capabilities = cmp_nvim_lsp.default_capabilities()
		local signs = { Error = "⛔", Warn = "⚠︎", Hint = "?", Info = "!" }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		mason_lspconfig.setup_handlers({
			-- default handler for installed servers
			function(server_name)
				lspconfig[server_name].setup({
					capabilities = capabilities,
				})
			end,
			["graphql"] = function()
				-- configure graphql language server
				lspconfig["graphql"].setup({
					capabilities = capabilities,
					filetypes = { "graphql", "gql", "typescriptreact", "javascriptreact" },
				})
			end,
			["emmet_ls"] = function()
				-- configure emmet language server
				lspconfig["emmet_ls"].setup({
					capabilities = capabilities,
					filetypes = {
						"html",
						"typescriptreact",
						"javascriptreact",
						"css",
						"sass",
						"scss",
						"less",
					},
				})
			end,
			["lua_ls"] = function()
				-- configure lua server (with special settings)
				lspconfig["lua_ls"].setup({
					capabilities = capabilities,
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},
							-- make the language server recognize "vim" global
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
				})
			end,
		})
	end,
}
