local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_go_mod(opts)
  return vim.fs.find("go.mod", { upward = true, type = "file", path = opts.dir })[1]
end

--- Detect if air (cosmtrek/air) is available and project has an air config
---@param project_dir string
---@return boolean has_air, string|nil err
local function check_air(project_dir)
  if vim.fn.executable("air") ~= 1 then
    return false, '"air" not found in PATH'
  end
  local air_conf =
    vim.fs.find({ ".air.toml", "air.toml", ".air.conf" }, { upward = false, type = "file", path = project_dir })[1]
  if not air_conf then
    return false, "No .air.toml found in project root"
  end
  return true, nil
end

--- Find the main package entrypoint directory
---@param project_dir string
---@return string|nil
local function find_main_dir(project_dir)
  -- Search recursively for main.go files (depth 6 to avoid deep vendored trees)
  local files = vim.fs.find("main.go", {
    upward = false,
    type = "file",
    path = project_dir,
    limit = 20,
    depth = 6,
  })
  for _, f in ipairs(files) do
    local fh = io.open(f, "r")
    if fh then
      local first_line = fh:read("*line")
      fh:close()
      if first_line and first_line:match("^package%s+main") then
        return vim.fs.dirname(f)
      end
    end
  end
  return nil
end

local commands = {
  { name = "Go Build", args = { "build", "./..." }, tags = { TAG.BUILD }, priority = 60 },
  { name = "Go Test", args = { "test", "./..." }, tags = { TAG.TEST }, priority = 60 },
  { name = "Go Test Verbose", args = { "test", "-v", "./..." }, tags = { TAG.TEST }, priority = 50 },
  { name = "Go Vet", args = { "vet", "./..." }, tags = { TAG.BUILD }, priority = 50 },
  { name = "Go Tidy", args = { "mod", "tidy" }, tags = { TAG.CLEAN }, priority = 50 },
  { name = "Go Generate", args = { "generate", "./..." }, tags = { TAG.BUILD }, priority = 40 },
  { name = "Go Fmt", args = { "fmt", "./..." }, tags = { TAG.CLEAN }, priority = 40 },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_go_mod(opts)
  end,
  generator = function(opts)
    local go_mod_path = find_go_mod(opts)
    if not go_mod_path then
      return "No go.mod found in project"
    end

    if vim.fn.executable("go") ~= 1 then
      return '"go" not found in PATH'
    end

    local project_dir = vim.fs.dirname(go_mod_path)
    local main_dir = find_main_dir(project_dir)
    local has_air, air_err = check_air(project_dir)

    local ret = {}

    -- Standard Go commands
    for _, cmd in ipairs(commands) do
      table.insert(ret, {
        name = cmd.name,
        priority = cmd.priority,
        tags = cmd.tags,
        builder = function()
          return {
            name = cmd.name,
            cmd = "go",
            args = cmd.args,
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Go Run (auto-detect main package entrypoint)
    if main_dir then
      local rel = main_dir
      if rel:sub(1, #project_dir) == project_dir then
        rel = "." .. rel:sub(#project_dir + 1)
      end

      table.insert(ret, {
        name = "Go Run",
        priority = 60,
        tags = { TAG.RUN },
        builder = function()
          return {
            name = "Go Run",
            cmd = "go",
            args = { "run", rel },
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Air hot reload (if available)
    if has_air then
      table.insert(ret, {
        name = "Air (hot reload)",
        priority = 60,
        tags = { TAG.RUN },
        builder = function()
          return {
            name = "Air (hot reload)",
            cmd = "air",
            args = {},
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Go Single Test — run test under cursor pattern
    table.insert(ret, {
      name = "Go Test (this package)",
      priority = 50,
      tags = { TAG.TEST },
      builder = function()
        local buf_path = vim.api.nvim_buf_get_name(0)
        local pkg_dir = vim.fs.dirname(buf_path)
        return {
          name = "Go Test (this package)",
          cmd = "go",
          args = { "test", pkg_dir },
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    -- Custom Go command
    table.insert(ret, {
      name = "Go Custom",
      priority = 30,
      tags = { TAG.RUN },
      params = {
        go_args = {
          type = "string",
          name = "Go arguments",
          desc = "Full go subcommand and arguments (e.g. run ./cmd/server -port=8080)",
          default = "run ./cmd/server",
        },
      },
      builder = function(params)
        local args = vim.split(params.go_args, "%s+", { trimempty = true })
        return {
          name = "go " .. params.go_args,
          cmd = "go",
          args = args,
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    -- Air custom args (only if air binary is installed, even without .air.toml)
    if vim.fn.executable("air") == 1 then
      table.insert(ret, {
        name = "Air Custom",
        priority = 20,
        tags = { TAG.RUN },
        params = {
          air_args = {
            type = "string",
            name = "Air arguments",
            desc = "Arguments for air (e.g. --build.cmd 'go build -o ./tmp/main ./cmd/server')",
            default = "",
          },
        },
        builder = function(params)
          local args = {}
          if params.air_args and params.air_args ~= "" then
            args = vim.split(params.air_args, "%s+", { trimempty = true })
          end
          return {
            name = "air " .. params.air_args,
            cmd = "air",
            args = args,
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    return ret
  end,
}
