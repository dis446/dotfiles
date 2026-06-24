 return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore_enabled = true, -- restore session on `nvim .`
      auto_save_enabled = true, -- save session on exit
      auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
      post_restore = {
        function()
          -- Session restore uses :badd internally, which doesn't fire BufReadPre/BufNewFile.
          -- Force-load lazy plugins (lspconfig, treesitter) that depend on those events.
          local ok, lazy = pcall(require, "lazy")
          if ok then
            lazy.load({ events = { "BufReadPre" } })
          end
          -- Re-attach LSP clients to all restored buffers
          pcall(vim.cmd.LspRestart)
        end,
      },
    })

    -- No manual keybinds needed. Just open nvim and it restores.
  end,
}
