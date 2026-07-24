require("dis446.core.options")
require("dis446.core.keymaps")

vim.api.nvim_create_user_command("GlabResolve", function()
  require("dis446.glab-secrets").resolve()
end, { desc = "Resolve $VAR placeholders from GitLab CI/CD variables" })

vim.api.nvim_create_user_command("GlabEnv", function(opts)
  require("dis446.glab-secrets").generate_env(opts.args)
end, { nargs = 1, complete = "file", desc = "Generate .env from GitLab CI YAML and resolve vars" })
