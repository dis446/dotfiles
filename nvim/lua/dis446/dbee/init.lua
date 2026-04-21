local repo = require("dis446.dbee.repo")
local Source = require("dis446.dbee.source")

local M = {}

local source = Source:new()
local source_name = source:name()

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "DBee" })
end

local function reload_source(root)
  source:set_root(root)
  require("dbee").api.core.source_reload(source_name)
  return source.last_loaded or repo.load_for_root(root)
end

local function describe_load(data)
  if not data.has_config then
    return string.format("No .nvim/dbee.lua for %s", data.repo_name), vim.log.levels.INFO
  end

  if #data.connections == 0 then
    return string.format("No valid DB connections for %s", data.repo_name), vim.log.levels.WARN
  end

  return string.format("Loaded %d DB connection(s) for %s", #data.connections, data.repo_name), vim.log.levels.INFO
end

function M.source()
  return source
end

function M.reload(opts)
  opts = opts or {}

  local root = opts.root or repo.current_root()
  local ok, data = pcall(reload_source, root)
  if not ok then
    notify("Failed reloading repo DB config: " .. data, vim.log.levels.ERROR)
    return nil
  end

  if not opts.silent then
    local message, level = describe_load(data)
    notify(message, level)
  end

  for _, warning in ipairs(data.warnings or {}) do
    notify(warning, vim.log.levels.WARN)
  end

  return data
end

function M.open()
  M.reload()
  require("dbee").open()
end

function M.toggle()
  M.reload()
  require("dbee").open()
end

function M.edit_config(local_config)
  local root = repo.current_root()
  local target = repo.ensure_config(root, local_config)
  vim.cmd.edit(vim.fn.fnameescape(target))
end

function M.setup_commands()
  vim.api.nvim_create_user_command("DbeeRepoOpen", function()
    M.open()
  end, { desc = "Open DBee with repo DB config" })

  vim.api.nvim_create_user_command("DbeeRepoToggle", function()
    M.toggle()
  end, { desc = "Open DBee with repo DB config" })

  vim.api.nvim_create_user_command("DbeeRepoReload", function()
    M.reload()
  end, { desc = "Reload repo DB connections" })

  vim.api.nvim_create_user_command("DbeeRepoEditConfig", function()
    M.edit_config(false)
  end, { desc = "Edit repo .nvim/dbee.lua" })

  vim.api.nvim_create_user_command("DbeeRepoEditLocalConfig", function()
    M.edit_config(true)
  end, { desc = "Edit repo .nvim/dbee.local.lua" })
end

function M.setup_keymaps()
  vim.keymap.set("n", "<leader>od", function()
    M.toggle()
  end, { desc = "Open DBee" })

  vim.keymap.set("n", "<leader>oD", function()
    M.reload()
  end, { desc = "Reload repo DB connections" })
end

return M
