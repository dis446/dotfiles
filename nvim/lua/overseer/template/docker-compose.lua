local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_compose_file(opts)
  return vim.fs.find({ "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" }, { upward = true, type = "file", path = opts.dir })[1]
end

--- Resolve docker compose command: prefer `docker compose`, fallback to standalone `docker-compose`
---@return string|nil cmd, nil|string reason, table|nil base_args
local function get_compose_cmd()
  -- Docker v2 has `docker compose` as a subcommand
  if vim.fn.executable("docker") == 1 then
    -- Quick check if `docker compose` works
    local ok = vim.fn.system({ "docker", "compose", "version" }):len() > 0 and vim.v.shell_error == 0
    if ok then
      return "docker", nil, { "compose" }
    end
  end
  -- Fallback to standalone docker-compose
  if vim.fn.executable("docker-compose") == 1 then
    return "docker-compose", nil, {}
  end
  return nil, 'Neither "docker compose" nor "docker-compose" found', nil
end

local commands = {
  { name = "DC Up Detached",  args = { "up", "-d" },             tags = { TAG.RUN },   priority = 50 },
  { name = "DC Down",         args = { "down" },                 tags = { TAG.CLEAN }, priority = 50 },
  { name = "DC Logs",         args = { "logs", "-f" },           tags = { TAG.RUN },   priority = 40 },
  { name = "DC Logs Tail",    args = { "logs", "-f", "--tail=100" }, tags = { TAG.RUN }, priority = 40 },
  { name = "DC PS",           args = { "ps" },                   tags = { TAG.RUN },   priority = 50 },
  { name = "DC Build",        args = { "build" },                tags = { TAG.BUILD }, priority = 50 },
  { name = "DC Build No Cache", args = { "build", "--no-cache" }, tags = { TAG.BUILD }, priority = 40 },
  { name = "DC Pull",         args = { "pull" },                 tags = { TAG.BUILD }, priority = 40 },
  { name = "DC Restart",      args = { "restart" },              tags = { TAG.RUN },   priority = 40 },
  { name = "DC Down Volumes", args = { "down", "-v" },           tags = { TAG.CLEAN }, priority = 30 },
  { name = "DC Stop",         args = { "stop" },                 tags = { TAG.CLEAN }, priority = 40 },
  { name = "DC Start",        args = { "start" },                tags = { TAG.RUN },   priority = 40 },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_compose_file(opts)
  end,
  generator = function(opts)
    local compose_path = find_compose_file(opts)
    if not compose_path then
      return "No docker-compose file found in project"
    end

    local project_dir = vim.fs.dirname(compose_path)
    local cmd, err, base_args = get_compose_cmd()
    if not cmd then
      return err
    end

    local ret = {}
    for _, c in ipairs(commands) do
      table.insert(ret, {
        name = c.name,
        priority = c.priority,
        tags = c.tags,
        builder = function()
          return {
            name = c.name,
            cmd = cmd,
            args = vim.list_extend(vim.deepcopy(base_args or {}), c.args),
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Custom compose command
    table.insert(ret, {
      name = "DC Custom",
      priority = 30,
      tags = { TAG.RUN },
      params = {
        compose_args = {
          type = "string",
          name = "Docker Compose args",
          desc = "Compose subcommand and flags (e.g. up -d --build)",
          default = "up -d",
        },
      },
      builder = function(params)
        local args = vim.split(params.compose_args, "%s+", { trimempty = true })
        local full_args = vim.list_extend(vim.deepcopy(base_args or {}), args)
        return {
          name = "docker compose " .. params.compose_args,
          cmd = cmd,
          args = full_args,
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    return ret
  end,
}
