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

opt.background = "dark"

opt.backspace = "indent,eol,start"

-- mise shims: ensures nvim finds mise-managed tools even outside a login shell
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

