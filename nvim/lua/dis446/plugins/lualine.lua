return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status") -- to configure lazy pending updates count

    -- component: show file path relative to the repo root (git top-level)
    local function repo_relative_filename()
      local filename = vim.api.nvim_buf_get_name(0)
      if filename == "" then
        return "[No Name]"
      end
      -- absolute filename
      filename = vim.fn.fnamemodify(filename, ':p')

      -- try to determine git root via git rev-parse (fast and reliable when available)
      local parent = vim.fn.fnamemodify(filename, ':h')
      local cmd = 'git -C ' .. vim.fn.shellescape(parent) .. ' rev-parse --show-toplevel 2>/dev/null'
      local root = vim.fn.systemlist(cmd)[1]

      if root == nil or root == "" then
        -- fallback to current working directory if not in a git repo
        root = vim.fn.getcwd()
      end

      -- normalize paths (remove trailing slashes)
      root = string.gsub(root, '/+$', '')
      filename = string.gsub(filename, '/+', '/')

      if filename:sub(1, #root) == root then
        local rel = filename:sub(#root + 2) -- strip root + '/'
        if rel == "" then
          return vim.fn.fnamemodify(filename, ':t')
        end
        return rel
      end

      -- if not under detected root, fall back to relative path to cwd (or absolute if same)
      local cwd_rel = vim.fn.fnamemodify(filename, ':~:.')
      return cwd_rel
    end

    local colors = {
      blue = "#65D1FF",
      green = "#3EFFDC",
      violet = "#FF61EF",
      yellow = "#FFDA7B",
      red = "#FF4A4A",
      fg = "#c3ccdc",
      fg_inactive = "#8FA7C0",
      bg = "#112638",
      inactive_bg = "#2c3043",
    }

    local my_lualine_theme = {
      normal = {
        a = { bg = colors.blue, fg = colors.bg, gui = "bold" },
        b = { bg = colors.bg, fg = colors.fg },
        c = { bg = colors.bg, fg = colors.fg },
      },
      insert = {
        a = { bg = colors.green, fg = colors.bg, gui = "bold" },
        b = { bg = colors.bg, fg = colors.fg },
        c = { bg = colors.bg, fg = colors.fg },
      },
      visual = {
        a = { bg = colors.violet, fg = colors.bg, gui = "bold" },
        b = { bg = colors.bg, fg = colors.fg },
        c = { bg = colors.bg, fg = colors.fg },
      },
      command = {
        a = { bg = colors.yellow, fg = colors.bg, gui = "bold" },
        b = { bg = colors.bg, fg = colors.fg },
        c = { bg = colors.bg, fg = colors.fg },
      },
      replace = {
        a = { bg = colors.red, fg = colors.bg, gui = "bold" },
        b = { bg = colors.bg, fg = colors.fg },
        c = { bg = colors.bg, fg = colors.fg },
      },
      inactive = {
        a = { bg = colors.inactive_bg, fg = colors.fg_inactive, gui = "bold" },
        b = { bg = colors.inactive_bg, fg = colors.fg_inactive },
        c = { bg = colors.inactive_bg, fg = colors.fg_inactive },
      },
    }

    -- configure lualine with modified theme; include our repo-relative filename component
    lualine.setup({
      options = {
        theme = my_lualine_theme,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {},
        lualine_c = {
          { repo_relative_filename, color = { fg = colors.fg } },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = "#ff9e64" },
          },
          { "encoding" },
          { "fileformat" },
          { "filetype" },
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
