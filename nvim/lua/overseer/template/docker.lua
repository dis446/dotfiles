local constants = require("overseer.constants")
local TAG = constants.TAG

---@return string|nil
local function find_dockerfile(opts)
  return vim.fs.find({ "Dockerfile", "Dockerfile.*" }, { upward = true, type = "file", path = opts.dir })[1]
end

--- Resolve docker command
---@return string|nil cmd, nil|string reason
local function get_docker_cmd()
  if vim.fn.executable("docker") == 1 then
    return "docker", nil
  end
  return nil, '"docker" not found in PATH'
end

local commands = {
  { name = "Docker PS",           args = { "ps" },                          tags = { TAG.RUN },  priority = 40 },
  { name = "Docker PS All",      args = { "ps", "-a" },                    tags = { TAG.RUN },  priority = 40 },
  { name = "Docker Images",      args = { "images" },                      tags = { TAG.RUN },  priority = 40 },
  { name = "Docker System DF",   args = { "system", "df" },                tags = { TAG.RUN },  priority = 30 },
  { name = "Docker Prune",       args = { "system", "prune", "-f" },       tags = { TAG.CLEAN }, priority = 40 },
  { name = "Docker Prune All",   args = { "system", "prune", "-af" },      tags = { TAG.CLEAN }, priority = 30 },
  { name = "Docker Build",       args = { "build", "-t", "myapp", "." },   tags = { TAG.BUILD }, priority = 50 },
  { name = "Docker Pull",        args = { "pull" },                        tags = { TAG.BUILD }, priority = 30 },
  { name = "Docker Logs",        args = { "logs", "-f" },                  tags = { TAG.RUN },  priority = 40 },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(_opts)
    -- Always show docker tasks if docker is installed
    if vim.fn.executable("docker") == 1 then
      return "docker"
    end
    return nil
  end,
  generator = function(opts)
    local docker_cmd, err = get_docker_cmd()
    if not docker_cmd then
      return err
    end

    local dockerfile_path = find_dockerfile(opts)
    local project_dir = dockerfile_path and vim.fs.dirname(dockerfile_path) or opts.dir or vim.fn.getcwd()

    local ret = {}
    for _, cmd in ipairs(commands) do
      table.insert(ret, {
        name = cmd.name,
        priority = cmd.priority,
        tags = cmd.tags,
        builder = function()
          return {
            name = cmd.name,
            cmd = docker_cmd,
            args = cmd.args,
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Custom docker command
    table.insert(ret, {
      name = "Docker Custom",
      priority = 30,
      tags = { TAG.RUN },
      params = {
        docker_args = {
          type = "string",
          name = "Docker args",
          desc = "Full docker arguments (e.g. exec -it mycontainer bash)",
          default = "ps -a",
        },
      },
      builder = function(params)
        local args = vim.split(params.docker_args, "%s+", { trimempty = true })
        return {
          name = "docker " .. params.docker_args,
          cmd = docker_cmd,
          args = args,
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    return ret
  end,
}
