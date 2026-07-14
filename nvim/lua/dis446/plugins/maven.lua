return {
  "oclay1st/maven.nvim",
  cmd = { "Maven", "MavenInit", "MavenExec", "MavenFavorites" },
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    mvn_executable = "mvn",
    project_scanner_depth = 5,
    console = {
      show_command_execution = true,
      show_lifecycle_execution = true,
      show_plugin_goal_execution = true,
    },
  },
  keys = {
    { "<leader>M", desc = "+Maven", mode = { "n", "v" } },
    { "<leader>mv", "<cmd>Maven<cr>", desc = "Maven Projects" },
    { "<leader>mf", "<cmd>MavenFavorites<cr>", desc = "Maven Favorites" },
  },
}
