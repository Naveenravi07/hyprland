vim.cmd("colorscheme  catppuccin")

-- Enable line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Set tabstop, softtabstop, shiftwidth, and expandtab
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Enable smart indenting
vim.opt.smartindent = true

-- Disable line wrapping
vim.opt.wrap = false

-- Disable swapfile and backup
vim.opt.swapfile = false
vim.opt.backup = false

-- Set the undodir to $HOME/.vim/undodir
vim.opt.undodir = vim.env.HOME .. "/.vim/undodir"

-- Enable undofile
vim.opt.undofile = true

-- Disable highlighting of search matches
vim.opt.hlsearch = false

-- Enable incremental search
vim.opt.incsearch = true

-- Enable termguicolors
vim.opt.termguicolors = true

-- Set the scrolloff and signcolumn
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

-- Append "@-@" to the 'isfname' option
vim.opt.isfname:append("@-@")

-- Set updatetime and clear colorcolumn
vim.opt.updatetime = 50
vim.opt.colorcolumn = ""

-- Set the signcolumn to 'auto'
vim.opt.signcolumn = "auto"

