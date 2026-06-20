vim.g.mapleader = " "

local keymap = vim.keymap


-- keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk"})
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights"})
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number"})
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number"})

-- window management
-- Removed split keybinds as they are handled by Zellij

keymap.set("n", "<leader>tt", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tw", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<C-Tab>", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<C-S-Tab>", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
