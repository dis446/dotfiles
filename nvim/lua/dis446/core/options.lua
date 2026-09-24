local opt = vim.opt

opt.relativenumber = true
opt.number = true
opt.ignorecase = true
opt.smartcase = true
opt.cursorline = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.clipboard:append("unnamedplus")

-- tabs and indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true

opt.wrap = false

-- Global statusline (one at bottom instead of per-window)
-- With lualine this gives a proper horizontal separator between splits
opt.laststatus = 3

opt.background = "dark"

opt.backspace = "indent,eol,start"

-- Window border-like separators (double lines for max visibility)
vim.opt.fillchars:append({
  horiz = '═',
  horizup = '╩',
  horizdown = '╦',
  vert = '║',
  vertleft = '╣',
  vertright = '╠',
  verthoriz = '╬',
})
vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#7aa2f7", bold = true })

-- mise shims: ensures nvim finds mise-managed tools even outside a login shell
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

-- herdr keeps ~35 pane nvims alive and each one spawns an `nvim --embed` child.
-- All of them wrote the same unlocked shada file, so a mass exit interleaved the
-- writes and corrupted it (E576/E136 on every later start). Nvim has no shada
-- locking, so inside herdr the only safe option is to not write one at all.
-- A nvim started outside herdr keeps full shada (a single writer).
-- ponytail: no cmdline/mark history in herdr nvims; give each workspace its own
-- shadafile if that history is ever wanted back.
if vim.env.HERDR_ENV == "1" then
  opt.shadafile = "NONE"
end
