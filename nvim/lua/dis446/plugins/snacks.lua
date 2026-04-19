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
          { icon = " ", key = "SPC ee", desc = "Toggle file explorer", action = function() Snacks.explorer() end },
          { icon = "󰱼 ", key = "SPC ff", desc = "Find File", action = function() Snacks.picker.files() end },
          { icon = " ", key = "SPC fs", desc = "Find Word", action = function() Snacks.picker.grep() end },
          { icon = "󰁯 ", key = "SPC wr", desc = "Restore Session For Current Directory", action = ":SessionRestore" },
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
      replace_netrw = true,
    },
    picker = {
      enabled = true,
      ui_select = false, -- phase 5: enable after dressing.nvim is removed
    },
    input = { enabled = false }, -- phase 5: enable after dressing.nvim is removed
    indent = { enabled = false }, -- phase 5: enable after indent-blankline is removed
    lazygit = { enabled = true },
    rename = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    local keymap = vim.keymap

    keymap.set("n", "<leader>ee", function()
      Snacks.explorer()
    end, { desc = "Toggle file explorer" })

    keymap.set("n", "<leader>ef", function()
      Snacks.explorer.reveal()
    end, { desc = "Reveal current file in explorer" })

    keymap.set("n", "<leader>ff", function()
      Snacks.picker.files()
    end, { desc = "Find files" })

    keymap.set("n", "<leader>fr", function()
      Snacks.picker.recent()
    end, { desc = "Find recent files" })

    keymap.set("n", "<leader>fs", function()
      Snacks.picker.grep()
    end, { desc = "Find string in cwd" })

    keymap.set("n", "<leader>fc", function()
      Snacks.picker.grep_word()
    end, { desc = "Find string under cursor in cwd" })

    keymap.set("n", "<leader>ft", function()
      Snacks.picker.todo_comments()
    end, { desc = "Find todos" })

    vim.api.nvim_create_user_command("SnacksExplorer", function()
      Snacks.explorer()
    end, { desc = "Open Snacks explorer" })

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
  end,
}
