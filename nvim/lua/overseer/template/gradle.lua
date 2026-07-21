local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_gradle_build(opts)
  return vim.fs.find({ "build.gradle", "build.gradle.kts" }, { upward = true, type = "file", path = opts.dir })[1]
end

--- Resolve Gradle command: prefer ./gradlew, fallback to system gradle
---@param project_dir string
---@return string|nil cmd, nil|string reason
local function get_gradle_cmd(project_dir)
  local gradlew = vim.fs.joinpath(project_dir, "gradlew")
  if vim.fn.filereadable(gradlew) == 1 then
    return gradlew, nil
  end
  if vim.fn.filereadable("./gradlew") == 1 then
    return "./gradlew", nil
  end
  if vim.fn.executable("gradle") == 1 then
    return "gradle", nil
  end
  return nil, 'Neither "gradlew" nor "gradle" found in project or PATH'
end

local commands = {
  { name = "Gradle Build",       tasks = { "build" },                 tags = { TAG.BUILD }, priority = 50 },
  { name = "Gradle Test",        tasks = { "test" },                  tags = { TAG.TEST },  priority = 50 },
  { name = "Gradle Clean",       tasks = { "clean" },                 tags = { TAG.CLEAN }, priority = 50 },
  { name = "Gradle Clean Build", tasks = { "clean", "build" },        tags = { TAG.BUILD }, priority = 50 },
  { name = "Gradle Classes",     tasks = { "classes" },               tags = { TAG.BUILD }, priority = 50 },
  { name = "Gradle Assemble",    tasks = { "assemble" },              tags = { TAG.BUILD }, priority = 40 },
  { name = "Gradle Check",       tasks = { "check" },                 tags = { TAG.BUILD }, priority = 40 },
  { name = "Gradle Quarkus Dev", tasks = { "quarkusDev" },            tags = { TAG.RUN },   priority = 50 },
  { name = "Gradle Skip Tests",  tasks = { "clean", "build", "-x", "test" }, tags = { TAG.BUILD }, priority = 50 },
  { name = "Gradle Dev Mode",    tasks = { "clean", "build", "-x", "test", "quarkusDev" }, tags = { TAG.RUN }, priority = 60 },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_gradle_build(opts)
  end,
  generator = function(opts)
    local build_path = find_gradle_build(opts)
    if not build_path then
      return 'No build.gradle or build.gradle.kts found in project'
    end

    local project_dir = vim.fs.dirname(build_path)
    local gradle_cmd, err = get_gradle_cmd(project_dir)
    if not gradle_cmd then
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
            cmd = gradle_cmd,
            args = cmd.tasks,
            cwd = project_dir,
            components = { "default" },
          }
        end,
      })
    end

    -- Custom Gradle task with parameter prompt
    table.insert(ret, {
      name = "Gradle Custom",
      priority = 30,
      tags = { TAG.RUN },
      params = {
        tasks = {
          type = "string",
          name = "Gradle tasks",
          desc = "Tasks and options (e.g. clean build -x test --info)",
          default = "clean build -x test",
        },
      },
      builder = function(params)
        local tasks = vim.split(params.tasks, "%s+", { trimempty = true })
        return {
          name = "Gradle: " .. params.tasks,
          cmd = gradle_cmd,
          args = tasks,
          cwd = project_dir,
          components = { "default" },
        }
      end,
    })

    return ret
  end,
}
