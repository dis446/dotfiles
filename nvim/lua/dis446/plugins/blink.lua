return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  -- use a release tag so the prebuilt Rust fuzzy-matcher binary is downloaded
  -- instead of requiring a local Rust toolchain to build it (see BLINK-MIGRATION.md)
  version = "1.*",
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      build = "make install_jsregexp",
    },
    "rafamadriz/friendly-snippets", -- useful snippets
  },
  config = function()
    -- loads vscode style snippets (e.g. friendly-snippets) into LuaSnip
    require("luasnip.loaders.from_vscode").lazy_load()

    require("blink.cmp").setup({
      snippets = { preset = "luasnip" },

      -- preserve the nvim-cmp keymap ergonomics. "fallback" lets the key fall
      -- through to its normal insert-mode behavior when the menu is closed.
      keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-k>"] = { "select_prev", "fallback" }, -- previous suggestion
        ["<C-j>"] = { "select_next", "fallback" }, -- next suggestion
        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" }, -- close completion window
        ["<CR>"] = { "accept", "fallback" }, -- confirm selection
      },

      completion = {
        -- match nvim-cmp's "noselect": nothing is preselected, <CR> only
        -- confirms an item you explicitly moved to with <C-j>/<C-k>
        list = {
          selection = { preselect = false, auto_insert = false },
        },
        documentation = {
          auto_show = true,
        },
        -- blink renders kind icons itself, so lspkind is no longer needed
        menu = {
          draw = {
            columns = {
              { "kind_icon", "label", gap = 1 },
              { "kind" },
            },
          },
        },
      },

      sources = {
        -- lsp, path, snippets and buffer are all built in
        default = { "lsp", "snippets", "buffer", "path" },
      },

      -- use the Rust matcher; warn (don't error) if the binary is unavailable
      fuzzy = { implementation = "prefer_rust_with_warning" },
    })
  end,
}
