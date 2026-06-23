return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    enabled = false,
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)

    vim.keymap.set("n", "<leader>tm", ":RenderMarkdown toggle<CR>",
      { desc = "Toggle markdown rendering" })
  end,
}
