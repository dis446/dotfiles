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
          { icon = " ", key = "SPC ee", desc = "Open file explorer", action = function() Snacks.explorer.open() end },
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
          exclude = { "**/node_modules/**", "**/.next/**", "**/.turbo/**", "**/out/**", "**/target/**", "**/build/**", "**/dist/**" },
          jump = { close = true },
        },
        files = {
          hidden = true,
          ignored = true,
          exclude = { "**/node_modules/**", "**/.next/**", "**/.turbo/**", "**/out/**", "**/target/**", "**/build/**", "**/dist/**" },
        },
        grep = {
          hidden = true,
          ignored = true,
          exclude = { "**/node_modules/**", "**/.next/**", "**/.turbo/**", "**/out/**", "**/target/**", "**/build/**", "**/dist/**" },
        },
        grep_word = {
          hidden = true,
          ignored = true,
          exclude = { "**/node_modules/**", "**/.next/**", "**/.turbo/**", "**/out/**", "**/target/**", "**/build/**", "**/dist/**" },
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

    local keymap = vim.keymap

    keymap.set("n", "<leader>ee", function()
      Snacks.explorer.open()
    end, { desc = "Open file explorer" })

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

    keymap.set("n", "<leader>lg", function()
      Snacks.lazygit()
    end, { desc = "Open lazy git" })

    keymap.set({ "n", "t" }, "<leader>ot", function()
      Snacks.terminal()
    end, { desc = "Toggle terminal" })

    keymap.set("n", "<leader>oT", function()
      Snacks.terminal(nil, {
        win = {
          position = "float",
          border = "rounded",
          width = 0.9,
          height = 0.9,
        },
      })
    end, { desc = "Open floating terminal" })

    keymap.set("n", "<leader>sm", function()
      Snacks.zen.zoom()
    end, { desc = "Maximize/minimize a split" })

    keymap.set("n", "<leader>xx", function()
      Snacks.picker.diagnostics()
    end, { desc = "Open diagnostics list" })

    keymap.set("n", "<leader>xw", function()
      Snacks.picker.diagnostics()
    end, { desc = "Open workspace diagnostics" })

    keymap.set("n", "<leader>xd", function()
      Snacks.picker.diagnostics_buffer()
    end, { desc = "Open document diagnostics" })

    keymap.set("n", "<leader>xq", function()
      Snacks.picker.qflist()
    end, { desc = "Open quickfix list" })

    keymap.set("n", "<leader>xl", function()
      Snacks.picker.loclist()
    end, { desc = "Open location list" })

    keymap.set("n", "<leader>xt", function()
      Snacks.picker.todo_comments()
    end, { desc = "Open todos list" })

    vim.api.nvim_create_user_command("SnacksExplorer", function()
      Snacks.explorer.open()
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
