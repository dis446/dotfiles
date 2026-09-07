local M = {}

-- When running inside herdr (HERDR_ENV=1), <M-k> routes pi to a real herdr
-- pane instead of a float. Direction the pi pane is split off: "right" or "down".
local herdr_split_direction = "right"

-- Pi keys its sessions by the cwd it starts in (default store
-- ~/.pi/agent/sessions/--<cwd>--), so pi must start with cwd = the canonical
-- project root and run plain `pi -c` (no --session-dir). Every launcher then
-- behaves exactly like typing `pi` in a terminal in that folder, and `pi -c`
-- resumes the same history.
--
-- Canonical root: the feature root when inside a feature workspace
-- (…/features/<name>/ or a worktree under it), else the git top-level.
-- Feature roots live inside the e2e umbrella repo, so a plain
-- `git rev-parse --show-toplevel` would resolve to the umbrella repo and hand
-- every feature worktree the same (wrong) root.
local function detect_root()
  local start_dir = vim.fn.getcwd()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" and not bufname:match("^term://") then
    start_dir = vim.fn.fnamemodify(bufname, ":p:h")
  end
  local feature_root = start_dir:match("^(.*/features/[^/]+)")
  if feature_root and vim.fn.isdirectory(feature_root) == 1 then
    return feature_root
  end
  local root = vim.fn.systemlist({ "git", "-C", start_dir, "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error == 0 and root and root ~= "" then
    root = vim.trim(root)
    if vim.fn.isdirectory(root) == 1 then
      return root
    end
  end
  return start_dir
end

local function in_herdr()
  return vim.env.HERDR_ENV == "1"
end

-- Run a herdr CLI command (JSON in/out). Returns decoded JSON or nil on failure.
local function herdr_cmd(args)
  local res = vim.system(args, { text = true }):wait()
  if res.code ~= 0 then
    local err = vim.trim(res.stderr ~= "" and res.stderr or res.stdout or "command failed")
    vim.notify("herdr: " .. err, vim.log.levels.ERROR)
    return nil
  end
  local ok, parsed = pcall(vim.json.decode, res.stdout)
  return ok and parsed or nil
end

-- Pane id of the pi agent already running in the current herdr workspace.
local function herdr_pi_pane()
  local res = herdr_cmd({ "herdr", "agent", "list" })
  if not res or not res.result or not res.result.agents then
    return nil
  end
  local ws = vim.env.HERDR_WORKSPACE_ID
  for _, agent in ipairs(res.result.agents) do
    if agent.agent == "pi" and agent.workspace_id == ws then
      return agent.pane_id
    end
  end
  return nil
end

-- M-k outside herdr (plain terminal): floating terminal, as before.
local function pi_float()
  local root = detect_root()
  Snacks.terminal.focus({ "pi", "-c" }, {
    cwd = root,
    win = {
      position = "float",
      border = "rounded",
      width = 0.9,
      height = 0.9,
    },
  })
end

-- M-k inside herdr: split the current pane and run pi there (focus it if already open).
-- cwd = canonical root and plain `pi -c`, so the session lives in pi's default
-- per-cwd store and resumes the same history as typing `pi` in the folder.
local function pi_herdr_pane()
  local root = detect_root()

  local existing = herdr_pi_pane()
  if existing then
    herdr_cmd({ "herdr", "agent", "focus", existing })
    return
  end

  local split = herdr_cmd({
    "herdr", "pane", "split", "--current",
    "--direction", herdr_split_direction,
    "--cwd", root,
    "--focus",
  })
  if not split then
    return pi_float() -- herdr unreachable: fall back to the float
  end
  local pane_id = split.result and split.result.pane and split.result.pane.pane_id
  if not pane_id then
    vim.notify("pi: could not parse herdr split result", vim.log.levels.ERROR)
    return
  end
  herdr_cmd({ "herdr", "pane", "run", pane_id, "pi -c" })
end

function M.setup()
  vim.keymap.set({ "n", "t" }, "<M-k>", function()
    if in_herdr() then
      pi_herdr_pane()
    else
      pi_float()
    end
  end, { desc = "Toggle Pi (herdr pane or float)" })
end

return M
