local map = vim.keymap.set

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

