return {
	"mfussenegger/nvim-jdtls",
	ft = "java",
	dependencies = {
		"neovim/nvim-lspconfig",
	},
	config = function()
		local jdtls = require("jdtls")
		local setup = require("jdtls.setup")

		-- `mise where` with an explicit tool@version ignores cwd; cache it (≤1 spawn per version per session).
		local java_homes = {}
		local function mise_home(flavor)
			if java_homes[flavor] == nil then
				local out = vim.fn.systemlist("mise where java@" .. flavor)
				java_homes[flavor] = (vim.v.shell_error == 0 and out[1] ~= nil) and out[1] or false
			end
			return java_homes[flavor] or nil
		end

		-- Hobby projects opt into 25 via a local mise.toml pinning java 25; everything else stays on 21.
		-- ponytail: substring match, parse maven.compiler.release if a second 25-signal ever appears.
		local function wants_java25(root_dir)
			for _, f in ipairs({ root_dir .. "/mise.toml", root_dir .. "/.mise.toml" }) do
				local ok, lines = pcall(vim.fn.readfile, f, "", 30)
				if ok and table.concat(lines, "\n"):match('java%s*=%s*"[^"]*25') then
					return true
				end
			end
			return false
		end

		local function attach(bufnr)
			vim.api.nvim_buf_call(bufnr, function()
				local root_dir = setup.find_root({
					"pom.xml",
					"mvnw",
					"gradlew",
					"build.gradle",
					"build.gradle.kts",
					".classpath",
					".project",
					"mise.toml",
					".mise.toml",
					"micronaut-cli.yml",
					".git",
				})

				if not root_dir then
					return
				end

				local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
				local workspace_dir = vim.fn.stdpath("data")
					.. "/jdtls/workspace/"
					.. project_name
					.. "-"
					.. vim.fn.sha256(root_dir):sub(1, 8)
				vim.fn.mkdir(workspace_dir, "p")

				local lombok_jar = vim.fn.stdpath("data") .. "/mason/packages/jdtls/lombok.jar"
				local cmd = { vim.fn.stdpath("data") .. "/mason/bin/jdtls" }
				if vim.fn.filereadable(lombok_jar) == 1 then
					table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok_jar)
				end

				-- Launcher JVM must be >= project level; work keeps its proven 21 launcher.
				local use25 = wants_java25(root_dir)
				local java21 = mise_home("temurin-21")
				local java25 = mise_home("temurin-25")
				local default_home = (use25 and java25 or java21)
					or vim.fn.fnamemodify(vim.fn.exepath("java"), ":h:h")
				local runtimes = {}
				for _, r in ipairs({ { name = "JavaSE-21", home = java21 }, { name = "JavaSE-25", home = java25 } }) do
					if r.home then
						table.insert(runtimes, { name = r.name, path = r.home, default = r.home == default_home })
					end
				end

				local java_bin = default_home ~= "" and default_home .. "/bin/java" or vim.fn.exepath("java")
				if java_bin ~= "" then
					table.insert(cmd, "--java-executable=" .. java_bin)
				end

				table.insert(cmd, "-data")
				table.insert(cmd, workspace_dir)

				jdtls.start_or_attach({
					cmd = cmd,
					root_dir = root_dir,
					init_options = {
						bundles = vim.list_extend(
						vim.fn.glob(
							vim.fn.stdpath("data")
								.. "/mason/packages/java-debug-adapter/extension/server/*.jar",
							false,
							true
						),
						vim.fn.glob(
							vim.fn.stdpath("data")
								.. "/mason/packages/java-test/extension/server/*.jar",
							false,
							true
						)
					),
						extendedClientCapabilities = jdtls.extendedClientCapabilities,
					},
					settings = {
						java = {
							format = {
								settings = {
									url = vim.fn.stdpath("config") .. "/style/eclipse-format.xml",
									profile = "Quarkus",
								},
							},
							completion = {
								importOrder = { "java", "javax", "jakarta", "org", "com" },
							},
							eclipse = {
								downloadSources = true,
							},
							maven = {
								downloadSources = true,
								updateSnapshots = true,
							},
							configuration = {
								updateBuildConfiguration = "automatic",
								runtimes = runtimes,
							},
							references = {
								includeDecompiledSources = true,
							},
							referencesCodeLens = {
								enabled = true,
							},
							implementationsCodeLens = {
								enabled = true,
							},
							signatureHelp = {
								enabled = true,
							},
							contentProvider = {
								preferred = "fernflower",
							},
							inlayHints = {
								parameterNames = {
									enabled = "all",
								},
							},
						},
					},
				})

				-- Set up Java DAP (requires java-debug-adapter + java-test from Mason)
				pcall(function()
					jdtls.setup_dap({ hotcodereplace = "auto" })

					-- Remove the dynamic provider so nvim-dap falls back to
					-- dap.configurations.java (static configs from dap.lua).
					-- The provider requires jdtls to already be connected and
					-- only finds apps with real main classes — it breaks the
					-- Quarkus attach workflow (no static main class).
					local dap = require("dap")
					if dap.providers and dap.providers.configs then
						dap.providers.configs["jdtls"] = nil
					end

					-- Schedule fetching real Launch configs once jdtls is ready
					vim.defer_fn(function()
						pcall(function()
							jdtls.setup_dap_main_class_configs({ verbose = false })
						end)
					end, 3000)
				end)

				-- Organize imports on save
				vim.api.nvim_create_autocmd("BufWritePre", {
					buffer = bufnr,
					callback = function()
						local timeout = 3000
						pcall(function()
							vim.lsp.buf.code_action({
								context = { only = { "source.organizeImports" } },
								apply = true,
								timeout = timeout,
							})
						end)
					end,
				})
			end)
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "java",
			callback = function(args)
				attach(args.buf)
			end,
		})

		attach(vim.api.nvim_get_current_buf())
	end,
}
