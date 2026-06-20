 return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore_enabled = true, -- restore session on `nvim .`
      auto_save_enabled = true, -- save session on exit
      auto_session_suppress_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" },
    })

    -- No manual keybinds needed. Just open nvim and it restores.
  end,
}
