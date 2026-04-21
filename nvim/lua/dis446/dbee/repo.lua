local env_file = require("dis446.dbee.env")

local M = {}

local function normalize_list(value)
  if value == nil then
    return {}
  end

  if type(value) == "table" then
    return vim.deepcopy(value)
  end

  return { value }
end

local function is_directory(path)
  local stat = path and vim.uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function starting_directory(path)
  if type(path) ~= "string" or path == "" then
    return vim.fn.getcwd()
  end

  if is_directory(path) then
    return vim.fs.normalize(path)
  end

  return vim.fs.normalize(vim.fs.dirname(path))
end

local function config_path(root, local_config)
  return vim.fs.joinpath(root, ".nvim", local_config and "dbee.local.lua" or "dbee.lua")
end

local function read_config_file(path)
  if not vim.uv.fs_stat(path) then
    return nil
  end

  local chunk, err = loadfile(path)
  if not chunk then
    error(string.format("failed loading %s: %s", path, err))
  end

  local ok, value = pcall(chunk)
  if not ok then
    error(string.format("failed evaluating %s: %s", path, value))
  end

  if value == nil then
    return {}
  end

  if type(value) ~= "table" then
    error(string.format("%s must return a table", path))
  end

  return value
end

local function merge_connections(base, override)
  local merged = {}
  local index = {}

  for _, connection in ipairs(base or {}) do
    if type(connection) == "table" and connection.name then
      local copy = vim.deepcopy(connection)
      index[copy.name] = #merged + 1
      table.insert(merged, copy)
    end
  end

  for _, connection in ipairs(override or {}) do
    if type(connection) == "table" and connection.name then
      local existing = index[connection.name]
      if existing then
        merged[existing] = vim.tbl_deep_extend("force", merged[existing], vim.deepcopy(connection))
      else
        index[connection.name] = #merged + 1
        table.insert(merged, vim.deepcopy(connection))
      end
    end
  end

  return merged
end

local function merge_specs(base, override)
  if not base and not override then
    return { connections = {} }
  end

  if not base then
    base = {}
  end

  if not override then
    override = {}
  end

  local merged = vim.tbl_deep_extend("force", {}, base, override)
  merged.connections = merge_connections(base.connections, override.connections)

  return merged
end

local function repo_name(root)
  return vim.fs.basename(root)
end

local function env_value(name, values)
  if not name or name == "" then
    return nil
  end

  local process_value = os.getenv(name)
  if process_value ~= nil and process_value ~= "" then
    return process_value
  end

  local file_value = values[name]
  if file_value ~= nil and file_value ~= "" then
    return file_value
  end

  return nil
end

local function resolve_value(connection, field, env_values)
  local direct = connection[field]
  if direct ~= nil and direct ~= "" then
    return direct
  end

  return env_value(connection[field .. "_env"], env_values)
end

local function encode_component(value)
  value = tostring(value or "")
  return value:gsub("([^%w%-._~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function build_query(params)
  local parts = {}

  for key, value in pairs(params or {}) do
    if value ~= nil and value ~= "" then
      table.insert(parts, encode_component(key) .. "=" .. encode_component(value))
    end
  end

  table.sort(parts)

  if #parts == 0 then
    return ""
  end

  return "?" .. table.concat(parts, "&")
end

local function normalize_type(value)
  if value == "postgresql" then
    return "postgres"
  end

  return value
end

local function build_url(connection, env_values)
  local explicit = resolve_value(connection, "url", env_values)
  if explicit then
    return explicit
  end

  local conn_type = normalize_type(resolve_value(connection, "type", env_values))
  local host = resolve_value(connection, "host", env_values)
  local port = resolve_value(connection, "port", env_values)
  local database = resolve_value(connection, "database", env_values)
  local user = resolve_value(connection, "user", env_values)
  local password = resolve_value(connection, "password", env_values)
  local params = vim.deepcopy(connection.params or {})

  if connection.sslmode and params.sslmode == nil then
    params.sslmode = connection.sslmode
  end

  if conn_type == "postgres" then
    if not host or not port or not database or not user or password == nil then
      return nil, "postgres connection needs host, port, database, user, password"
    end

    local query = build_query(params)
    local url = string.format(
      "postgres://%s:%s@%s:%s/%s%s",
      encode_component(user),
      encode_component(password),
      tostring(host),
      tostring(port),
      encode_component(database),
      query
    )

    return url
  end

  if conn_type == "mysql" then
    if not host or not port or not database or not user or password == nil then
      return nil, "mysql connection needs host, port, database, user, password"
    end

    local query = build_query(params)
    local url = string.format(
      "%s:%s@tcp(%s:%s)/%s%s",
      encode_component(user),
      encode_component(password),
      tostring(host),
      tostring(port),
      tostring(database),
      query
    )

    return url
  end

  return nil, string.format("unsupported connection type: %s", tostring(conn_type))
end

local function build_connection(root, config, connection)
  local env_files = {}
  vim.list_extend(env_files, normalize_list(config.env_files))
  vim.list_extend(env_files, normalize_list(connection.env_files))

  local env_values = env_file.load(root, env_files)
  local conn_type = normalize_type(resolve_value(connection, "type", env_values))
  local name = resolve_value(connection, "name", env_values)

  if not name or name == "" then
    return nil, "connection is missing name"
  end

  if not conn_type or conn_type == "" then
    return nil, string.format("connection %s is missing type", name)
  end

  local url, err = build_url(vim.tbl_extend("keep", { type = conn_type }, connection), env_values)
  if not url then
    return nil, string.format("connection %s invalid: %s", name, err)
  end

  return {
    id = "repo_dbee_" .. vim.fn.sha256(root .. "::" .. name):sub(1, 16),
    name = string.format("%s/%s", repo_name(root), name),
    type = conn_type,
    url = url,
  }
end

function M.config_paths(root)
  return {
    shared = config_path(root, false),
    ["local"] = config_path(root, true),
  }
end

function M.find_root(path)
  local dir = starting_directory(path)
  local found = vim.fs.find({ ".nvim/dbee.lua", ".git" }, {
    upward = true,
    path = dir,
  })[1]

  if found then
    if found:match("/%.git$") then
      return vim.fs.normalize(vim.fs.dirname(found))
    end

    return vim.fs.normalize(vim.fs.dirname(vim.fs.dirname(found)))
  end

  return dir
end

function M.current_root()
  local buffer_name = vim.api.nvim_buf_get_name(0)
  return M.find_root(buffer_name ~= "" and buffer_name or vim.fn.getcwd())
end

function M.ensure_config(root, local_config)
  local paths = M.config_paths(root)
  local target = local_config and paths["local"] or paths.shared

  vim.fn.mkdir(vim.fs.dirname(target), "p")

  if not vim.uv.fs_stat(target) then
    local lines
    if local_config then
      lines = {
        "return {",
        "  connections = {",
        "    -- { name = \"local\", port = 5433 },",
        "  },",
        "}",
        "",
      }
    else
      lines = {
        "return {",
        "  connections = {",
        "    {",
        "      name = \"local\",",
        "      type = \"postgres\",",
        "      env_files = { \".env\" },",
        "      host = \"127.0.0.1\",",
        "      port = 5432,",
        "      database_env = \"DB_NAME\",",
        "      user_env = \"DB_USER\",",
        "      password_env = \"DB_PASS\",",
        "      sslmode = \"disable\",",
        "    },",
        "  },",
        "}",
        "",
      }
    end

    vim.fn.writefile(lines, target)
  end

  return target
end

function M.load_for_root(root)
  root = M.find_root(root)

  local paths = M.config_paths(root)
  local warnings = {}
  local base
  local local_override

  local ok, value = pcall(read_config_file, paths.shared)
  if ok then
    base = value
  elseif value then
    table.insert(warnings, value)
  end

  ok, value = pcall(read_config_file, paths["local"])
  if ok then
    local_override = value
  elseif value then
    table.insert(warnings, value)
  end

  local config = merge_specs(base, local_override)
  local connections = {}

  for _, connection in ipairs(config.connections or {}) do
    local built, err = build_connection(root, config, connection)
    if built then
      table.insert(connections, built)
    elseif err then
      table.insert(warnings, err)
    end
  end

  table.sort(connections, function(left, right)
    return left.name < right.name
  end)

  return {
    root = root,
    repo_name = repo_name(root),
    config_path = paths.shared,
    local_config_path = paths["local"],
    has_config = vim.uv.fs_stat(paths.shared) ~= nil or vim.uv.fs_stat(paths["local"]) ~= nil,
    connections = connections,
    warnings = warnings,
  }
end

return M
