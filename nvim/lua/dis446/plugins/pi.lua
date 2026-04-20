return {
  "nvim-lua/plenary.nvim",
  cmd = { "Pi", "PiToggle", "PiNew" },
  keys = {
    { "<leader>pi", "<cmd>PiToggle<cr>", desc = "Toggle Pi AI" },
    { "<leader>pI", "<cmd>PiNew<cr>", desc = "Start new Pi session" },
  },
  config = function()
    local state = {}

    local function sanitize(str)
      return (str:gsub("[^%w._-]", "_"))
    end

    local function detect_root()
      local start_dir = vim.fn.getcwd()
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname ~= "" then
        start_dir = vim.fn.fnamemodify(bufname, ":p:h")
      end

      local root = vim.fn.systemlist({ "git", "-C", start_dir, "rev-parse", "--show-toplevel" })[1]
      if vim.v.shell_error == 0 and root and root ~= "" then
        return root
      end

      return start_dir
    end

    local function session_dir_for_root(root)
      local base = vim.fn.stdpath("state") .. "/pi-sessions"
      local id = sanitize(vim.fn.fnamemodify(root, ":t")) .. "-" .. vim.fn.sha256(root):sub(1, 12)
      local dir = base .. "/" .. id
      vim.fn.mkdir(dir, "p")
      return dir
    end

    local function has_existing_sessions(dir)
      return #vim.fn.globpath(dir, "**/*.jsonl", false, true) > 0
    end

    local function is_job_running(job_id)
      if not job_id or job_id <= 0 then
        return false
      end
      return vim.fn.jobwait({ job_id }, 0)[1] == -1
    end

    local function get_session(dir)
      state[dir] = state[dir] or {
        buf = nil,
        win = nil,
        job_id = nil,
        root = nil,
        dir = dir,
      }
      return state[dir]
    end

    local function close_pane(session)
      if session.win and vim.api.nvim_win_is_valid(session.win) then
        vim.api.nvim_win_close(session.win, true)
      end
      session.win = nil
    end

    local function attach_close_mapping(session)
      local opts = {
        buffer = session.buf,
        silent = true,
        noremap = true,
        nowait = true,
        desc = "Close Pi pane",
      }

      vim.keymap.set("t", "<C-x>", function()
        close_pane(session)
      end, opts)

      vim.keymap.set("n", "<C-x>", function()
        close_pane(session)
      end, opts)
    end

    local function ensure_buffer(session)
      if session.buf and vim.api.nvim_buf_is_valid(session.buf) then
        return
      end

      session.buf = vim.api.nvim_create_buf(false, true)
      vim.bo[session.buf].bufhidden = "hide"
      vim.bo[session.buf].swapfile = false
      vim.bo[session.buf].filetype = "pi"
      attach_close_mapping(session)
    end

    local function start_terminal(session, force_new)
      ensure_buffer(session)
      vim.api.nvim_set_current_win(session.win)
      vim.api.nvim_win_set_buf(session.win, session.buf)

      local cmd = { "pi", "--session-dir", session.dir }
      if not force_new and has_existing_sessions(session.dir) then
        table.insert(cmd, 2, "-c")
      end

      session.job_id = vim.fn.termopen(cmd, {
        cwd = session.root,
        on_exit = function()
          session.job_id = nil
        end,
      })

      attach_close_mapping(session)
    end

    local function pane_width()
      return math.max(50, math.floor(vim.o.columns * 0.33))
    end

    local function set_window_options(win)
      vim.wo[win].number = false
      vim.wo[win].relativenumber = false
      vim.wo[win].signcolumn = "no"
      vim.wo[win].wrap = true
      vim.wo[win].winfixwidth = true
      vim.wo[win].winbar = " [Pi] Ctrl+X close "
    end

    local function open_pane(force_new)
      local root = detect_root()
      local session_dir = session_dir_for_root(root)
      local session = get_session(session_dir)
      session.root = root

      if session.win and vim.api.nvim_win_is_valid(session.win) then
        vim.api.nvim_set_current_win(session.win)
        vim.api.nvim_win_set_width(session.win, pane_width())
        if force_new or not is_job_running(session.job_id) then
          session.job_id = nil
          start_terminal(session, force_new)
        end
        set_window_options(session.win)
        vim.cmd("startinsert")
        return
      end

      ensure_buffer(session)

      vim.cmd("botright vsplit")
      session.win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_width(session.win, pane_width())
      vim.api.nvim_win_set_buf(session.win, session.buf)
      set_window_options(session.win)

      if force_new then
        session.job_id = nil
      end

      if not is_job_running(session.job_id) then
        start_terminal(session, force_new)
      end

      vim.cmd("startinsert")
    end

    vim.api.nvim_create_user_command("Pi", function()
      open_pane(false)
    end, {})

    vim.api.nvim_create_user_command("PiToggle", function()
      local root = detect_root()
      local session_dir = session_dir_for_root(root)
      local session = get_session(session_dir)
      session.root = root

      if session.win and vim.api.nvim_win_is_valid(session.win) then
        if vim.api.nvim_get_current_win() == session.win then
          close_pane(session)
        else
          vim.api.nvim_set_current_win(session.win)
          vim.api.nvim_win_set_width(session.win, pane_width())
          vim.cmd("startinsert")
        end
        return
      end

      open_pane(false)
    end, {})

    vim.api.nvim_create_user_command("PiNew", function()
      open_pane(true)
    end, {})
  end,
}
