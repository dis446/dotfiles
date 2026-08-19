local M = {}

-- When running inside herdr (HERDR_ENV=1), <M-k> routes pi to a real herdr
-- pane instead of a float. Direction the pi pane is split off: "right" or "down".
local herdr_split_direction = "right"

local function detect_root()
  local start_dir = vim.fn.getcwd()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" and not bufname:match("^term://") then
    start_dir = vim.fn.fnamemodify(bufname, ":p:h")
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

local function pi_session_dir(root)
  local base = vim.fn.stdpath("state") .. "/pi-sessions"
  local name = vim.fn.fnamemodify(root, ":t"):gsub("[^%w._-]", "_")
  local hash = vim.fn.sha256(root):sub(1, 12)
  local dir = base .. "/" .. name .. "-" .. hash
  vim.fn.mkdir(dir, "p")
  return dir
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

-- M-k outside herdr (plain terminal / tmux): floating terminal, as before.
local function pi_float()
  local root = detect_root()
  local session_dir = pi_session_dir(root)

  Snacks.terminal.focus({ "pi", "-c", "--session-dir", session_dir }, {
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
-- Same deterministic session dir as the float, so `pi -c` resumes the same session.
local function pi_herdr_pane()
  local root = detect_root()
  local session_dir = pi_session_dir(root)

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
  herdr_cmd({ "herdr", "pane", "run", pane_id, "pi -c --session-dir " .. session_dir })
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
