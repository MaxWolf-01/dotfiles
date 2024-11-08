local map = vim.keymap.set

-- ====================================================================
-- basic
-- ====================================================================

-- disable U (scary behvaior)
map("n", "U", "<NOP>", { noremap = true, silent = true })
-- centered cursor when scrolling
map("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
map("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })
-- ctrl+s saves in both normal and insert modes; insert returns to insert
map("n", "<C-s>", ":w<CR>", { noremap = true, silent = true })
map("i", "<C-s>", "<Esc>:w<CR>a", { noremap = true, silent = true })
-- preserve paste register when pasting over selection
map("x", "<leader>p", "\"_dP", { noremap = true, silent = true })

-- ====================================================================
-- lsp
-- ====================================================================

map("n", "gD", vim.lsp.buf.declaration, { silent = true })
map("n", "gd", vim.lsp.buf.definition, { silent = true })
map("n", "gi", vim.lsp.buf.implementation, { silent = true })
map("n", "gs", vim.lsp.buf.signature_help, { silent = true })
-- TODO see :help vim.lsp.buf<Tab>

-- ====================================================================
-- diagnostic
-- ====================================================================

map("n", "[d", vim.diagnostic.goto_prev, { silent = true })
map("n", "]d", vim.diagnostic.goto_next, { silent = true })
map("n", "gef", vim.diagnostic.open_float, { silent = true })
map("n", "geq", vim.diagnostic.setqflist, { silent = true })

-- ====================================================================
-- oil
-- ====================================================================

map("n", "-", "<CMD>Oil<CR>", { silent = true })

-- ====================================================================
-- telescope
-- ====================================================================

map("n", "<leader>ff", ":Telescope find_files<CR>", { silent = true })
map("n", "<leader>fw", ":Telescope live_grep<CR>", { silent = true })
map("n", "<leader>fb", ":Telescope buffers<CR>", { silent = true })
map("n", "gi", ":Telescope lsp_implementations<CR>", { silent = true })
map("n", "gd", ":Telescope lsp_definitions<CR>", { silent = true })
map("n", "gr", ":Telescope lsp_references<CR>", { silent = true })
map("n", "gl", ":Telescope diagnostics<CR>", { silent = true })

-- https://github.com/lukasl-dev/nixos/blob/master/dots/nvim/lua/mappings.lua
