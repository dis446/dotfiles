local M = {}

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

local function pi_terminal()
  local root = detect_root()
  local session_dir = pi_session_dir(root)
  local has_sessions = #vim.fn.globpath(session_dir, "**/*.jsonl", false, true) > 0

  local cmd = { "pi", "--session-dir", session_dir }
  if has_sessions then
    table.insert(cmd, 2, "-c")
  end

  Snacks.terminal.focus(cmd, {
    cwd = root,
    win = {
      position = "float",
      border = "rounded",
      width = 0.9,
      height = 0.9,
    },
  })
end

function M.setup()
  vim.keymap.set({ "n", "t" }, "<M-k>", pi_terminal, { desc = "Toggle Pi" })
end

return M
