-- Resolve $VAR / ${VAR} placeholders from GitLab CI/CD variables via glab CLI.
-- Shows a floating progress panel; non-blocking, dismiss with 'q'.
local M = {}

local SCOPE_MAP = {
  dev = "alpha-dev",
  sit = "alpha-ptf-sit",
  uat = "alpha-ptf-uat",
  test = "alpha-test",
  demo = "alpha-demo",
  preview = "alpha-preview",
  th = "alpha-th",
  prod = "alpha-prod",
}

local SCOPE_REVERSE = {
  ["alpha-dev"] = "dev",
  ["alpha-ptf-sit"] = "sit",
  ["alpha-ptf-uat"] = "uat",
  ["alpha-test"] = "test",
  ["alpha-demo"] = "demo",
  ["alpha-preview"] = "preview",
  ["alpha-th"] = "th",
  ["alpha-prod"] = "prod",
}


function M.detect_scope()
  local fname = vim.fn.expand("%:t")
  local suffix = fname:match("%.env%.(.+)$")
  if suffix and SCOPE_MAP[suffix] then
    return SCOPE_MAP[suffix]
  end
  local fullpath = vim.fn.expand("%:p")
  local scope = fullpath:match("([%w%-]+)%.ya?ml$")
  if scope then
    return scope
  end
  return nil
end

function M.collect_vars(lines)
  local vars = {}
  for _, line in ipairs(lines) do
    for var in line:gmatch("%$([A-Z][A-Z0-9_]*)") do
      vars[var] = true
    end
    for var in line:gmatch("%${([A-Z][A-Z0-9_]*)}") do
      vars[var] = true
    end
  end
  return vim.tbl_keys(vars)
end

--- Create a floating window and return { buf, win }.
local function create_float(title, height)
  local buf = vim.api.nvim_create_buf(false, true)
  local win_w = 65
  local win_h = math.max(height, 5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_w,
    height = win_h,
    col = (vim.o.columns - win_w) / 2,
    row = (vim.o.lines - win_h) / 2 - 2,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", { nowait = true, silent = true })
  return buf, win
end

--- Draw the current status lines into the float buffer.
local function redraw(buf, scope, vars, status, done_count, total)
  local lines = {}
  table.insert(lines, string.format("Scope: %s  |  %d/%d resolved", scope, done_count, total))
  table.insert(lines, "")
  for _, var in ipairs(vars) do
    local s = status[var]
    if s == "ok" then
      table.insert(lines, "  ✓ " .. var)
    elseif s == "retry" then
      table.insert(lines, "  ↻ " .. var)
    elseif s == "fail" then
      table.insert(lines, "  ✗ " .. var)
    else
      table.insert(lines, "  … " .. var)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Auto-resize if needed
  local win = vim.fn.bufwinid(buf)
  if win > 0 then
    local new_h = math.max(#lines + 2, 5)
    vim.api.nvim_win_set_height(win, new_h)
  end
end

--- Build final report lines to append after all jobs finish.
local function final_report(status, vars, total, resolved_count, failed_vars, retry_scope)
  local lines = {}
  table.insert(lines, "")
  table.insert(lines, string.rep("─", 60))
  table.insert(lines, string.format("Done.  ✓ %d resolved  ✗ %d failed  (of %d)", resolved_count, #failed_vars, total))

  if #failed_vars > 0 then
    table.insert(lines, "")
    table.insert(lines, "Failed variables:")
    for _, v in ipairs(failed_vars) do
      table.insert(lines, "  • " .. v)
    end
  end

  if retry_scope then
    table.insert(lines, "")
    table.insert(lines, string.format("Fallback scope used: %s", retry_scope))
  end

  table.insert(lines, "")
  table.insert(lines, "Press q or Esc to close")
  return lines
end

--- Apply replacements to the source buffer.
local function apply_replacements(src_buf, src_lines, replacements)
  -- Sort by name length descending so ESIGN_CONTRACT_* replaces before ESIGN_*
  local sorted = vim.tbl_keys(replacements)
  table.sort(sorted, function(a, b) return #a > #b end)

  local new_lines = {}
  for _, line in ipairs(src_lines) do
    local nl = line
    for _, var in ipairs(sorted) do
      local val = replacements[var]
      -- Escape % in the value: gsub treats % specially in the *replacement* string,
      -- so a value like Firebase SA JSON containing %40 raised "invalid capture index"
      -- and aborted the whole replacement (leaving every $VAR unresolved).
      local esc_val = val:gsub("%%", "%%%%")
      -- ${VAR} first (exact match), then $VAR (end-of-line aware via [^%w]?)
      nl = nl:gsub("%${" .. var .. "}", esc_val)
      nl = nl:gsub("%$" .. var .. "([^%w]?)", esc_val .. "%1")
    end
    table.insert(new_lines, nl)
  end
  vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, new_lines)
end

--- Spawn async glab jobs for a list of vars against a scope. Calls on_done() when all finish.
--- @param target_scope string|nil  if nil, runs "glab variable get VAR" with no scope flag
local function spawn_jobs(var_list, target_scope, replacements, status, on_done)
  local pending = #var_list
  if pending == 0 then
    vim.schedule(on_done)
    return
  end

  for _, var in ipairs(var_list) do
    local args = { "glab", "variable", "get", var, "-F", "json" }
    if target_scope then
      table.insert(args, 5, "-s")
      table.insert(args, 6, target_scope)
    end

    local job_id = vim.fn.jobstart(args, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = vim.schedule_wrap(function(_, data)
        if not data then
          return
        end
        local raw = table.concat(data, "")
        local ok, decoded = pcall(vim.json.decode, raw)
        if ok and decoded.value then
          replacements[var] = decoded.value
          status[var] = "ok"
        else
          status[var] = "fail"
        end
      end),
      on_exit = vim.schedule_wrap(function()
        if not status[var] or status[var] == "retry" then
          status[var] = "fail"
        end
        pending = pending - 1
        if pending <= 0 then
          -- Tally results for this batch
          for _, v in ipairs(var_list) do
            if status[v] == "ok" then
              -- only count once (may have resolved in prior phase)
            end
          end
          on_done()
        end
      end),
    })

    if job_id <= 0 then
      status[var] = "fail"
      pending = pending - 1
      if pending <= 0 then
        vim.schedule(on_done)
      end
    end
  end
end

function M.resolve()
  local scope = M.detect_scope()
  if not scope then
    scope = vim.fn.input("GitLab scope: ")
  end
  if not scope or scope == "" then
    vim.notify("No scope provided", vim.log.levels.WARN)
    return
  end

  local src_buf = vim.api.nvim_get_current_buf()
  local src_lines = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)

  local vars = M.collect_vars(src_lines)
  if #vars == 0 then
    vim.notify("No $VAR placeholders found", vim.log.levels.INFO)
    return
  end

  -- State
  local status = {} -- "ok" | "fail" | "retry" | nil (pending)
  local replacements = {}
  local total = #vars
  local resolved_count = 0
  local failed_vars = {}
  local retry_scope = nil -- nil means "no -s flag" (default project scope)

  -- Create floating progress window
  local float_win_id = nil
  local float_buf = nil

  local function init_float(title_str)
    local b, w = create_float(title_str, total + 7)
    float_buf = b
    float_win_id = w
  end

  local function update_redraw()
    if not float_buf then
      return
    end
    redraw(float_buf, scope, vars, status, resolved_count, total)
  end

  init_float("glab " .. scope)
  update_redraw()

  -- Called after ALL phases complete.
  local function on_all_done()
    -- Apply successful replacements
    if resolved_count > 0 then
      apply_replacements(src_buf, src_lines, replacements)
    end

    -- Tally final failed_vars
    local final_failed = {}
    for _, var in ipairs(vars) do
      if status[var] == "fail" then
        table.insert(final_failed, var)
      end
    end

    -- Append final report
    local report = final_report(status, vars, total, resolved_count, final_failed, retry_scope)
    local existing = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
    for _, line in ipairs(report) do
      table.insert(existing, line)
    end
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, existing)

    -- Resize
    local win = vim.fn.bufwinid(float_buf)
    if win > 0 then
      vim.api.nvim_win_set_height(win, #existing + 1)
    end
  end

  -- Phase 2/3: retry failed vars with fallback scopes.
  -- Phase 2 = project default (no -s flag).
  -- Phase 3 = "*" (all-environments) — required for masked vars like SONAR_*,
  -- which glab only returns when queried with -s "*" (no-flag 404s).
  local function retry_phase(phase_scope, phase_label)
    local retry_vars = {}
    for _, var in ipairs(vars) do
      if status[var] == "fail" then
        table.insert(retry_vars, var)
        status[var] = "retry"
      end
    end

    if #retry_vars == 0 then
      on_all_done()
      return
    end

    retry_scope = phase_label
    -- Update float title
    if float_win_id then
      pcall(vim.api.nvim_win_set_config, float_win_id, {
        title = " glab " .. scope .. " → " .. phase_label .. " ",
        title_pos = "center",
      })
    end
    update_redraw()

    spawn_jobs(retry_vars, phase_scope, replacements, status, function()
      local still_failed = false
      -- Re-tally: successful retries
      for _, var in ipairs(retry_vars) do
        if status[var] == "ok" then
          resolved_count = resolved_count + 1
        elseif status[var] == "fail" then
          still_failed = true
        end
      end
      if still_failed and phase_scope == nil then
        -- Last fallback: variables at "*" (all-environments) scope
        retry_phase("*", "all-env")
      else
        update_redraw()
        on_all_done()
      end
    end)
  end

  -- Phase 1: try detected scope --
  spawn_jobs(vars, scope, replacements, status, function()
    -- Tally phase 1 results
    for _, var in ipairs(vars) do
      if status[var] == "ok" then
        resolved_count = resolved_count + 1
      elseif status[var] == "fail" then
        table.insert(failed_vars, var)
      end
    end
    update_redraw()
    retry_phase(nil, "project default")
  end)
end

--- Variant: resolve then copy the whole buffer to system clipboard.
function M.resolve_and_copy()
  M.resolve()
  -- Copy after replacement (async — needs a hook; simple version: copy what we have)
  vim.schedule(function()
    local total = vim.api.nvim_buf_line_count(0)
    local lines = vim.api.nvim_buf_get_lines(0, 0, total, false)
    vim.fn.setreg("+", table.concat(lines, "\n"))
    vim.notify("Resolved env copied to clipboard", vim.log.levels.INFO)
  end)
end

--- Parse GitLab CI YAML env entries into KEY=VALUE lines.
local function parse_yaml_env(yaml_lines)
  local env = {}
  local in_env = false
  local current_name = nil

  for _, line in ipairs(yaml_lines) do
    if line:match("^%s*env:") then
      in_env = true
    elseif in_env then
      local name_match = line:match("^%s*-%s*name:%s*(%S+)")
      if name_match then
        current_name = name_match
      elseif current_name then
        -- Strip YAML quoting: try double-quoted, then single-quoted, then bare token.
        local value_match = line:match("^%s*value:%s*\"([^\"]*)\"")
          or line:match("^%s*value:%s*'([^']*)'")
          or line:match("^%s*value:%s*(%S+)")
        if value_match then
          table.insert(env, current_name .. "=" .. value_match)
          current_name = nil
        end
      end
      -- Exit env section on a non-indented, non-list line
      if not line:match("^%s") and not line:match("^%s*-") and not line:match("^%s*$") then
        in_env = false
      end
    end
  end

  return env
end

--- Generate .env file from a GitLab CI YAML, then resolve $VAR placeholders.
--- @param yaml_path string  path relative to git root, e.g. ".gitlab/alpha-test.yaml"
function M.generate_env(yaml_path)
  if not yaml_path or yaml_path == "" then
    vim.notify("Usage: GlabEnv .gitlab/alpha-test.yaml", vim.log.levels.ERROR)
    return
  end

  -- Detect scope from YAML filename
  local scope = yaml_path:match("([%w%-]+)%.ya?ml$")
  if not scope then
    vim.notify("Could not detect scope from filename: " .. yaml_path, vim.log.levels.ERROR)
    return
  end

  local suffix = SCOPE_REVERSE[scope]
  if not suffix then
    vim.notify("Unknown scope: " .. scope, vim.log.levels.ERROR)
    return
  end

  -- Git repo root
  local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error ~= 0 or not root or root == "" then
    vim.notify("Not inside a git repository", vim.log.levels.ERROR)
    return
  end

  local full_yaml = root .. "/" .. yaml_path
  local yaml_lines = vim.fn.readfile(full_yaml)
  if #yaml_lines == 0 then
    vim.notify("Could not read: " .. full_yaml, vim.log.levels.ERROR)
    return
  end

  -- Parse env entries
  local env_lines = parse_yaml_env(yaml_lines)
  if #env_lines == 0 then
    vim.notify("No env entries found in " .. yaml_path, vim.log.levels.WARN)
    return
  end

  -- Write .env file
  local env_file = root .. "/.env." .. suffix
  vim.fn.writefile(env_lines, env_file)
  vim.notify(string.format("Created %s (%d vars)", ".env." .. suffix, #env_lines), vim.log.levels.INFO)

  -- Open in buffer
  vim.cmd("edit " .. vim.fn.fnameescape(env_file))

  -- Resolve $VAR placeholders
  M.resolve()
end

return M
