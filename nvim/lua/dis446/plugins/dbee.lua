return {
  "kndndrj/nvim-dbee",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  build = function()
    require("dbee").install()
  end,
  config = function()
    local repo_dbee = require("dis446.dbee")

    require("dbee").setup({
      sources = {
        repo_dbee.source(),
      },
    })

    repo_dbee.setup_commands()
    repo_dbee.setup_keymaps()
  end,
}
