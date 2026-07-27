return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      enabled = true,
      preset = {
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        keys = {
          { icon = " ", key = "e", desc = "New File", action = ":ene | startinsert" },
          {
            icon = " ",
            key = "SPC ee",
            desc = "Toggle file explorer",
            action = function()
              Snacks.explorer()
            end,
          },
          {
            icon = "󰱼 ",
            key = "SPC ff",
            desc = "Find File",
            action = function()
              Snacks.picker.files()
            end,
          },
          {
            icon = " ",
            key = "SPC fs",
            desc = "Find Word",
            action = function()
              Snacks.picker.grep()
            end,
          },
          {
            icon = "󰁯 ",
            key = "SPC wr",
            desc = "Restore Session For Current Directory",
            action = ":SessionRestore",
          },
          { icon = " ", key = "q", desc = "Quit NVIM", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
    explorer = {
      enabled = true,
      -- Keep explorer manual-only. Don't auto-open on directory buffers.
      replace_netrw = false,
    },
    picker = {
      enabled = true,
      ui_select = true,
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          exclude = {
            "**/node_modules/**",
            "**/.next/**",
            "**/.turbo/**",
            "**/.venv/**",
            "**/out/**",
            "**/target/**",
            "**/build/**",
            "**/dist/**",
            "**/tmp/**",
            "**/.nx/**",
          },
          -- make explorer wider: set sidebar width (fraction of total width). Default ~0.33, set to 0.66 for ~2x width
          layout = { preset = "sidebar", preview = false, width = 0.66 },
          jump = { close = true },
          win = {
            list = {
              keys = {
                ["d"] = { "explorer_del", mode = { "n", "x" } },
              },
            },
          },
        },

        files = {
          hidden = true,
          ignored = true,
          exclude = {
            "**/node_modules/**",
            "**/.next/**",
            "**/.turbo/**",
            "**/.venv/**",
            "**/out/**",
            "**/target/**",
            "**/build/**",
            "**/dist/**",
            "**/tmp/**",
            "**/logs/**",
            "**/.nx/**",
          },
        },
        grep = {
          hidden = true,
          ignored = true,
          exclude = {
            "**/node_modules/**",
            "**/.next/**",
            "**/.turbo/**",
            "**/.venv/**",
            "**/out/**",
            "**/target/**",
            "**/build/**",
            "**/dist/**",
            "**/tmp/**",
            "**/logs/**",
            "**/.nx/**",
          },
        },
        grep_word = {
          hidden = true,
          ignored = true,
          exclude = {
            "**/node_modules/**",
            "**/.next/**",
            "**/.turbo/**",
            "**/.venv/**",
            "**/out/**",
            "**/target/**",
            "**/build/**",
            "**/dist/**",
            "**/tmp/**",
            "**/logs/**",
            "**/.nx/**",
          },
        },
      },
    },
    input = { enabled = true },
    indent = { enabled = true },
    lazygit = { enabled = true },
    rename = { enabled = true },
    terminal = {},
    zen = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    -- Pi coding agent integration
    require("dis446.pi").setup()

    vim.api.nvim_create_user_command("SnacksExplorer", function()
      Snacks.explorer()
    end, { desc = "Toggle Snacks explorer" })

    vim.api.nvim_create_user_command("SnacksReveal", function()
      Snacks.explorer.reveal()
    end, { desc = "Reveal current file in Snacks explorer" })

    vim.api.nvim_create_user_command("SnacksFiles", function()
      Snacks.picker.files()
    end, { desc = "Open Snacks file picker" })

    vim.api.nvim_create_user_command("SnacksRecent", function()
      Snacks.picker.recent()
    end, { desc = "Open Snacks recent files picker" })

    vim.api.nvim_create_user_command("SnacksGrep", function()
      Snacks.picker.grep()
    end, { desc = "Open Snacks grep picker" })

    vim.api.nvim_create_user_command("SnacksLazyGit", function()
      Snacks.lazygit()
    end, { desc = "Open Snacks lazygit" })

    vim.api.nvim_create_user_command("SnacksTerminal", function()
      Snacks.terminal()
    end, { desc = "Toggle Snacks terminal" })

    vim.api.nvim_create_user_command("SnacksTerminalFloat", function()
      Snacks.terminal(nil, {
        win = {
          position = "float",
          border = "rounded",
          width = 0.9,
          height = 0.9,
        },
      })
    end, { desc = "Open floating Snacks terminal" })
  end,
}
