return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local bufferline = require("bufferline")
    bufferline.setup({
      options = {
        mode = "buffers",
        numbers = "ordinal",
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = nil,
        indicator = {
          icon = "▎",
          style = "icon",
        },
        buffer_close_icon = "",
        modified_icon = "●",
        close_icon = "",
        left_trunc_marker = "",
        right_trunc_marker = "",
        separator_style = "thick",
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level, _, _)
          local icon = level:match("error") and " " or " "
          return " " .. icon .. count
        end,
        offsets = {
          {
            filetype = "NvimTree",
            text = "File Explorer",
            highlight = "Directory",
            separator = true,
          },
        },
        show_buffer_close_icons = true,
        show_close_icon = true,
        show_tab_indicators = true,
        persist_buffer_sort = true,
        sort_by = "insert_after_current",
        maximum_padding = 1,
        minimum_padding = 1,
        maximum_length = 30,
        enforce_regular_tabs = false,
        always_show_bufferline = true,
        hover = {
          enabled = true,
          delay = 200,
          reveal = { "close" },
        },
      },
      highlights = {
        background = {
          fg = "#8FA7C0",
          bg = "#0B1A2B",
        },
        buffer_selected = {
          fg = "#c3ccdc",
          bg = "#112638",
          bold = true,
          italic = false,
        },
        buffer_visible = {
          fg = "#8FA7C0",
          bg = "#0B1A2B",
        },
        close_button = {
          fg = "#8FA7C0",
          bg = "#0B1A2B",
        },
        close_button_selected = {
          fg = "#FF4A4A",
          bg = "#112638",
        },
        indicator_selected = {
          fg = "#65D1FF",
          bg = "#112638",
        },
        tab_selected = {
          fg = "#65D1FF",
          bg = "#112638",
        },
        tab = {
          fg = "#8FA7C0",
          bg = "#0B1A2B",
        },
        tab_close = {
          fg = "#FF4A4A",
          bg = "#0B1A2B",
        },
        modified = {
          fg = "#FFDA7B",
          bg = "#0B1A2B",
        },
        modified_selected = {
          fg = "#FFDA7B",
          bg = "#112638",
        },
        duplicate_selected = {
          fg = "#8FA7C0",
          bg = "#112638",
          italic = true,
        },
        duplicate_visible = {
          fg = "#8FA7C0",
          bg = "#0B1A2B",
          italic = true,
        },
        separator = {
          fg = "#0F1E2F",
          bg = "#0B1A2B",
        },
        separator_selected = {
          fg = "#0F1E2F",
          bg = "#112638",
        },
        -- diagnostics
        error = {
          fg = "#FF4A4A",
        },
        error_diagnostic = {
          fg = "#FF4A4A",
        },
        warning = {
          fg = "#FFDA7B",
        },
        warning_diagnostic = {
          fg = "#FFDA7B",
        },
        info = {
          fg = "#65D1FF",
        },
        info_diagnostic = {
          fg = "#65D1FF",
        },
        hint = {
          fg = "#3EFFDC",
        },
        hint_diagnostic = {
          fg = "#3EFFDC",
        },
      },
    })
  end,
}
