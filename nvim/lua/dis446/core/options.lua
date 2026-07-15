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

