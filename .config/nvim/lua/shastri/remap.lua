vim.g.mapleader = " "
vim.g.ttimeoutlen=100
vim.opt.relativenumber = true
vim.keymap.set("n", "<leader>kv", vim.cmd.Ex)
vim.keymap.set("t", "<leader>kv", vim.cmd.Ex)

vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- This is used to select the highlighted text and move wherever you needed
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")


vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]]) --this copies to global buffer
vim.keymap.set("n", "<leader>Y", [["+Y]])        --this copies to neovim buffer
