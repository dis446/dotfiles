return {
  "stevearc/overseer.nvim",
  -- pin removed -- fetched latest on install
  cmd = { "OverseerRun", "OverseerToggle", "OverseerQuickAction", "OverseerTaskAction", "OverseerBuild" },
  opts = {
    -- Load builtin templates + user/project templates
    templates = { "builtin", "user" },
    task_list = {
      direction = "bottom",
      min_height = 10,
      max_height = 15,
      default_detail = 1,
    },
    -- Auto-detect npm scripts, Makefile, etc.
    strategy = {
      "process",
      "terminal",
    },
    component_aliases = {
      default = {
        "on_exit_set_status",
        "on_complete_notify",
        { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
        { "open_output", on_start = "always", direction = "dock" },
      },
    },
  },
  keys = {
    { "<leader>m",  group = "+Build & Run",                                   mode = { "n", "v" } },
    { "<leader>mm", "<cmd>OverseerRun<cr>",                                    desc = "Run task" },
    { "<leader>mr", "<cmd>OverseerQuickAction<cr>",                            desc = "Rerun last" },
    { "<leader>mk", "<cmd>OverseerTaskAction<cr>",                             desc = "Task actions (stop)" },
    { "<leader>m,", "<cmd>OverseerToggle<cr>",                                 desc = "Toggle task list" },
    { "<leader>mn", function() require("dap").continue() end,                  desc = "Start debug" },
    { "<leader>mb", "<cmd>OverseerBuild<cr>",                                  desc = "Build task" },
    { "<leader>mc", "<cmd>OverseerQuickAction run.cancel<cr>",                 desc = "Cancel task" },
  },
}
