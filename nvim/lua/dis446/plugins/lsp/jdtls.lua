return {
	"mfussenegger/nvim-jdtls",
	ft = "java",
	dependencies = {
		"neovim/nvim-lspconfig",
	},
	config = function()
		local jdtls = require("jdtls")
		local setup = require("jdtls.setup")

		local function find_java21()
			local candidates = {
				"/usr/lib/jvm/java-21-openjdk",
				"/usr/lib/jvm/java-21-openjdk-amd64",
				"/home/neddy/.jdks/corretto-21.0.8",
				"/home/neddy/.jdks/corretto-21.0.10",
				"/home/neddy/.jdks/ms-21.0.8",
				"/home/neddy/.jdks/graalvm-ce-21.0.2",
			}

			if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then
				table.insert(candidates, 1, vim.env.JAVA_HOME)
			end

			for _, java_home in ipairs(candidates) do
				if java_home and java_home ~= "" and vim.fn.executable(java_home .. "/bin/java") == 1 then
					local java_bin = java_home .. "/bin/java"
					local version = table.concat(vim.fn.systemlist(java_bin .. " -version 2>&1"), "\n")
					if version:match('version "21') then
						return java_home, java_bin
					end
				end
			end

			return nil, vim.fn.exepath("java")
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
				end

				local java_home, java_bin = find_java21()
				local runtimes = {}
				if java_home then
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
