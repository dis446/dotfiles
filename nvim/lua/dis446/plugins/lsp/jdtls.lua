return {
	"mfussenegger/nvim-jdtls",
	ft = "java",
	dependencies = {
		"neovim/nvim-lspconfig",
	},
	config = function()
		local jdtls = require("jdtls")
		local setup = require("jdtls.setup")

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
					"micronaut-cli.yml",
					".git",
				})

				if not root_dir then
					return
				end

				local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
				local workspace_dir = vim.fn.stdpath("data") .. "/jdtls/workspace/" .. project_name .. "-" .. vim.fn.sha256(root_dir):sub(1, 8)
				vim.fn.mkdir(workspace_dir, "p")

				local lombok_jar = vim.fn.stdpath("data") .. "/mason/packages/jdtls/lombok.jar"
				local cmd = { vim.fn.stdpath("data") .. "/mason/bin/jdtls" }
				if vim.fn.filereadable(lombok_jar) == 1 then
					table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok_jar)
					table.insert(cmd, "--jvm-arg=-Xbootclasspath/a:" .. lombok_jar)
				end

				local java_home = vim.env.JAVA_HOME
				local java_bin = vim.fn.exepath("java")
				local runtimes = {}
				if java_home and java_home ~= "" then
					table.insert(runtimes, {
						name = "JavaSE-21",
						path = java_home,
						default = true,
					})
				end

				if java_bin ~= "" then
					table.insert(cmd, "--java-executable=" .. java_bin)
				end

				table.insert(cmd, "-data")
				table.insert(cmd, workspace_dir)

				jdtls.start_or_attach({
					cmd = cmd,
					root_dir = root_dir,
					init_options = {
						bundles = {},
						extendedClientCapabilities = jdtls.extendedClientCapabilities,
					},
					settings = {
						java = {
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
