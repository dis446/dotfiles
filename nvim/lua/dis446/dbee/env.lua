local M = {}

local function strip_inline_comment(value)
  local comment_start = value:find("%s#")
  if comment_start then
    return vim.trim(value:sub(1, comment_start - 1))
  end

  return value
end

local function unquote(value)
  value = vim.trim(value or "")
  if value == "" then
    return ""
  end

  local first = value:sub(1, 1)
  local last = value:sub(-1)

  if (first == '"' or first == "'") and first == last then
    value = value:sub(2, -2)

    if first == '"' then
      value = value:gsub("\\n", "\n")
      value = value:gsub('\\"', '"')
    else
      value = value:gsub("\\'", "'")
    end

    value = value:gsub("\\\\", "\\")
    return value
  end

  return strip_inline_comment(value)
end

function M.read_file(path)
  local values = {}

  if not path or not vim.uv.fs_stat(path) then
    return values
  end

  for line in io.lines(path) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not vim.startswith(trimmed, "#") then
      local key, value = trimmed:match("^export%s+([%w_][%w%d_]*)%s*=%s*(.*)$")
      if not key then
        key, value = trimmed:match("^([%w_][%w%d_]*)%s*=%s*(.*)$")
      end

      if key then
        values[key] = unquote(value)
      end
    end
  end

  return values
end

function M.load(root, files)
  local values = {}
  local seen = {}

  for _, file in ipairs(files or {}) do
    if type(file) == "string" and file ~= "" then
      local path = file
      if not vim.startswith(path, "/") then
        path = vim.fs.joinpath(root, path)
      end

      path = vim.fs.normalize(path)
      if not seen[path] then
        seen[path] = true
        values = vim.tbl_extend("force", values, M.read_file(path))
      end
    end
  end

  return values
end

return M
