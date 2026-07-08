return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			-- UI widgets: breakpoints, stack frames, watches, REPL
			"rcarriga/nvim-dap-ui",
			-- Inline variable values at cursor
			"theHamsta/nvim-dap-virtual-text",
			-- Install DAP adapters via Mason
			{
				"jay-babu/mason-nvim-dap.nvim",
				dependencies = "williamboman/mason.nvim",
				opts = {
					automatic_installation = true,
					ensure_installed = {
						"python", -- debugpy
						"js-debug-adapter", -- vscode-js-debug (JS/TS)
						"java-debug-adapter", -- Java (loaded as jdtls bundle)
						"java-test", -- Java test runner (jdtls bundle)
					},
					handlers = {},
				},
			},
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- ── DAP UI layout ──────────────────────────────────────
			dapui.setup({
				icons = { expanded = "▾", collapsed = "▸" },
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.50 },
							{ id = "breakpoints", size = 0.25 },
							{ id = "stacks", size = 0.25 },
						},
						size = 50,
						position = "right",
					},
					{
						elements = {
							{ id = "repl", size = 0.50 },
							{ id = "watches", size = 0.50 },
						},
						size = 12,
						position = "bottom",
					},
				},
			})

			-- ── Virtual text ──────────────────────────────────────
			require("nvim-dap-virtual-text").setup({
				enabled = true,
				virt_text_pos = "eol",
			})

			-- ── Auto-open / close UI with debug session ───────────
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- ── Adapter configurations ────────────────────────────

			-- Python: debugpy via Mason's bundled venv
			dap.adapters.python = {
				type = "executable",
				command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
				args = { "-m", "debugpy.adapter" },
			}
			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					-- cwd matches the file's directory; override in .vscode/launch.json
					cwd = "${workspaceFolder}",
					justMyCode = true,
				},
				{
					type = "python",
					request = "launch",
					name = "Launch file (no-justMyCode)",
					program = "${file}",
					cwd = "${workspaceFolder}",
					justMyCode = false,
				},
			}

			-- JS/TS: vscode-js-debug (pwa-node protocol)
			local js_adapter_path = vim.fn.stdpath("data")
				.. "/mason/packages/js-debug-adapter"
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "127.0.0.1",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						js_adapter_path .. "/js-debug/src/dapDebugServer.js",
						"${port}",
					},
				},
			}
			for _, lang in ipairs({
				"typescript",
				"javascript",
				"typescriptreact",
				"javascriptreact",
			}) do
				dap.configurations[lang] = dap.configurations[lang] or {}
				table.insert(dap.configurations[lang], {
					type = "pwa-node",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					cwd = "${workspaceFolder}",
					runtimeExecutable = "node",
				})
				table.insert(dap.configurations[lang], {
					type = "pwa-node",
					request = "launch",
					name = "Launch with tsx",
					program = "${file}",
					cwd = "${workspaceFolder}",
					runtimeExecutable = "tsx",
				})
			end

			-- Go: Delve
			dap.adapters.delve = {
				type = "server",
				port = "${port}",
				executable = {
					command = "dlv",
					args = { "dap", "-l", "127.0.0.1:${port}" },
				},
			}
			dap.configurations.go = dap.configurations.go or {}
			table.insert(dap.configurations.go, {
				type = "delve",
				request = "launch",
				name = "Debug file",
				program = "${file}",
			})
			table.insert(dap.configurations.go, {
				type = "delve",
				request = "launch",
				name = "Debug test",
				mode = "test",
				program = "${workspaceFolder}",
			})

			-- Java: DAP flows through nvim-jdtls (set up via
			-- lua/dis446/plugins/lsp/jdtls.lua). The java-debug-adapter
			-- and java-test Mason packages are installed there.

			-- Attach config for remote JVMs (Quarkus dev mode, standalone apps)
			dap.configurations.java = dap.configurations.java or {}
			table.insert(dap.configurations.java, {
				name = "Attach (port 5005)",
				type = "java",
				request = "attach",
				hostName = "127.0.0.1",
				port = 5005,
			})
		end,
	},
}
