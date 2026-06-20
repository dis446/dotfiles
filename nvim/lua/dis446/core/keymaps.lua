vim.g.mapleader = " "

local keymap = vim.keymap

-- ── File & project navigation ───────────────────────
keymap.set("n", "<leader>ee", function() Snacks.explorer() end, { desc = "Toggle file explorer" })
keymap.set("n", "<leader>ef", function() Snacks.explorer.reveal() end, { desc = "Reveal current file in explorer" })
keymap.set("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Find file by name" })
keymap.set("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent files" })
keymap.set("n", "<leader>fs", function() Snacks.picker.grep() end, { desc = "Search text in project (grep)" })
keymap.set("n", "<leader>fc", function() Snacks.picker.grep_word() end, { desc = "Search word under cursor" })
keymap.set("n", "<leader>ft", function() Snacks.picker.todo_comments() end, { desc = "Find TODOs" })

-- ── Git ─────────────────────────────────────────────
keymap.set("n", "<leader>lg", function() Snacks.lazygit() end, { desc = "LazyGit (full TUI)" })
keymap.set("n", "<leader>lc", function() Snacks.lazygit() end, { desc = "Commit (lazygit)" })
keymap.set("n", "<leader>lp", function() Snacks.lazygit() end, { desc = "Push (lazygit)" })
keymap.set("n", "<leader>lu", function() Snacks.lazygit() end, { desc = "Pull (lazygit)" })

-- ── LSP / code intelligence ─────────────────────────
-- Global LSP mappings (using Snacks picker where appropriate)
keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Go to definition" })
keymap.set("n", "gi", function() Snacks.picker.lsp_implementations() end, { desc = "Go to implementation" })
keymap.set("n", "gt", function() Snacks.picker.lsp_type_definitions() end, { desc = "Go to type definition" })
keymap.set("n", "gR", function() Snacks.picker.lsp_references() end, { desc = "Find references" })
keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover / documentation" })
keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions / intentions" })
keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
keymap.set("n", "<leader>xx", function() Snacks.picker.diagnostics() end, { desc = "Toggle diagnostics list" })
keymap.set("n", "<leader>xd", function() Snacks.picker.diagnostics_buffer() end, { desc = "Buffer diagnostics" })

-- ── Terminal ────────────────────────────────────────
keymap.set({ "n", "t" }, "<leader>ot", function() Snacks.terminal() end, { desc = "Toggle terminal" })
keymap.set("n", "<leader>oT", function()
	Snacks.terminal(nil, {
		win = { position = "float", border = "rounded", width = 0.9, height = 0.9 },
	})
end, { desc = "Floating terminal" })

-- ── Build & run ─────────────────────────────────────
keymap.set("n", "<leader>rb", function()
	print("Use zellij bash pane for run")
end, { desc = "Run (Zellij)" })

-- ── Tools ───────────────────────────────────────────
keymap.set("n", "<leader>pi", function()
	print("Use Pi in separate zellij pane")
end, { desc = "AI Assistant (Zellij)" })
keymap.set("n", "<leader>db", function()
	print("Use DataGrip for database")
end, { desc = "Database (DataGrip)" })
keymap.set("n", "<leader>mv", function()
	print("Use zellij bash pane for maven")
end, { desc = "Maven (Zellij)" })

-- ── General editing ─────────────────────────────────
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- ── Tabs ────────────────────────────────────────────
keymap.set("n", "<leader>tt", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tw", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<C-Tab>", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<C-S-Tab>", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
