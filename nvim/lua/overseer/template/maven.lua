local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_pom(opts)
  return vim.fs.find("pom.xml", { upward = true, type = "file", path = opts.dir })[1]
end

--- Resolve Maven command: prefer ./mvnw, fallback to system mvn
---@param project_dir string
---@return string|nil cmd, nil|string reason
local function get_mvn_cmd(project_dir)
  local mvnw = vim.fs.joinpath(project_dir, "mvnw")
  if vim.fn.filereadable(mvnw) == 1 then
    return mvnw, nil
  end
  if vim.fn.filereadable("./mvnw") == 1 then
    return "./mvnw", nil
  end
  if vim.fn.executable("mvn") == 1 then
    return "mvn", nil
  end
  return nil, 'Neither "mvnw" nor "mvn" found in project or PATH'
end

local commands = {
  { name = "Maven Compile",       goals = { "compile" },                    tags = { TAG.BUILD }, priority = 50 },
  { name = "Maven Test",          goals = { "test" },                       tags = { TAG.TEST },  priority = 50 },
  { name = "Maven Package",       goals = { "package" },                    tags = { TAG.BUILD }, priority = 50 },
  { name = "Maven Clean",         goals = { "clean" },                      tags = { TAG.CLEAN }, priority = 50 },
  { name = "Maven Clean Package", goals = { "clean", "package" },           tags = { TAG.BUILD }, priority = 50 },
  { name = "Maven Install",       goals = { "install" },                    tags = { TAG.BUILD }, priority = 40 },
  { name = "Maven Verify",        goals = { "verify" },                     tags = { TAG.BUILD }, priority = 40 },
  { name = "Maven Quarkus Dev",   goals = { "quarkus:dev" },                tags = { TAG.RUN },   priority = 50 },
  { name = "Maven Skip Tests",    goals = { "clean", "package", "-DskipTests" }, tags = { TAG.BUILD }, priority = 50 },
  { name = "Maven Dev Mode",      goals = { "-DskipTests", "clean", "package", "quarkus:dev" }, tags = { TAG.RUN }, priority = 60 },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_pom(opts)
  end,
  generator = function(opts)
    local pom_path = find_pom(opts)
    if not pom_path then
      return "No pom.xml found in project"
    end

    local project_dir = vim.fs.dirname(pom_path)
    local mvn_cmd, err = get_mvn_cmd(project_dir)
    if not mvn_cmd then
      return err
    end

    local ret = {}
    for _, cmd in ipairs(commands) do
      table.insert(ret, {
        name = cmd.name,
        priority = cmd.priority,
        tags = cmd.tags,
        builder = function()
          return {
            name = cmd.name,
            cmd = mvn_cmd,
            args = vim.list_extend({ "-f", pom_path }, cmd.goals),
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Custom Maven goal with parameter prompt
    table.insert(ret, {
      name = "Maven Custom",
      priority = 30,
      tags = { TAG.RUN },
      params = {
        goals = {
          type = "string",
          name = "Maven goals",
          desc = "Goals and options (e.g. clean package -DskipTests)",
          default = "clean package -DskipTests",
        },
      },
      builder = function(params)
        local goals = vim.split(params.goals, "%s+", { trimempty = true })
        return {
          name = "Maven: " .. params.goals,
          cmd = mvn_cmd,
          args = vim.list_extend({ "-f", pom_path }, goals),
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    return ret
  end,
}
