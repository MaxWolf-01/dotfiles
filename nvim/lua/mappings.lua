-- TODO restructure with claude, add comments as descriptions

local map = vim.keymap.set
local opts = {    -- default options
  noremap = true, -- non-recursive, i.e. ignore other mappings; true per default
  silent = true,  -- prevents command from being echoed in the command line
}

-- ====================================================================
-- basic
-- ====================================================================

map("n", "<leader><leader>", ":Dashboard<CR>", opts) -- show dashboard: https://github.com/nvimdev/dashboard-nvim
map("n", "U", "<NOP>", opts)                         -- disable U (scary behvaior)
map("n", "<leader>ca", ":%y<CR>", opts)              -- copy all
-- Scroling and finding
map("n", "<C-d>", "<C-d>zz", opts)                   -- centered cursor when scrolling down
map("n", "<C-u>", "<C-u>zz", opts)                   -- centered cursor when scrolling up
map('n', 'n', 'nzzzv')                               -- next search result stays centered
map('n', 'N', 'Nzzzv')                               -- previous search result stays centered
-- Clear highlights on search when pressing <Esc> in normal mode. See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
-- Saving and quitting
map("n", "<C-s>", ":w<CR>", opts)                  -- ctrl+s saves in normal ...
map("i", "<C-s>", "<Esc>:w<CR>a", opts)            -- ... and in insert mode returns to insert
map('n', '<leader>ww', ':w<CR>')                   -- save with space+ww
map('n', '<leader>wq', ':wq<CR>')                  -- quit with space+wq
map('n', '<leader>qq', ':q<CR>')                   -- save quit with space+qq
map("x", "<leader>p", "\"_dP", opts)               -- preserve paste register when pasting over selection
-- Directory Navigation
map('n', '<leader>cd', ':cd %:p:h<CR>:pwd<CR>')    -- cd to dir of current file and show it
map('n', '<leader>cdww', ':lcd %:p:h<CR>:pwd<CR>') -- window-local cd to dir of current file and show it
map('n', '<leader>cdr', function()                 -- cd to git root of current file (if in git repo)
  local handle = io.popen('git rev-parse --is-inside-work-tree 2>/dev/null')
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then -- If in git repo
      vim.cmd('cd ' .. vim.fn.system('git rev-parse --show-toplevel'):gsub('\n', ''))
      vim.cmd('pwd')
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end)
map('n', '<leader>cdwr', function() -- window-local cd to git root of current file (if in git repo)
  local handle = io.popen('git rev-parse --is-inside-work-tree 2>/dev/null')
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then -- If in git repo
      vim.cmd('lcd ' .. vim.fn.system('git rev-parse --show-toplevel'):gsub('\n', ''))
      vim.cmd('pwd')
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end)
-- window splits
map('n', '<leader>vv', ':vsplit<CR>', opts)
map('n', '<leader>vh', ':split<CR>', opts)
-- window resizing
map('n', '<S-A-h>', ':vertical resize +4<CR>', opts)
map('n', '<S-A-j>', ':resize -4<CR>', opts)
map('n', '<S-A-k>', ':resize +4<CR>', opts)
-- use ALT+{h,j,k,l} to navigate windows from any mode
map("t", "<A-h>", "<C-\\><C-N><C-w>h", opts)
map("t", "<A-j>", "<C-\\><C-N><C-w>j", opts)
map("t", "<A-k>", "<C-\\><C-N><C-w>k", opts)
map("t", "<A-l>", "<C-\\><C-N><C-w>l", opts)
map("i", "<A-h>", "<C-\\><C-N><C-w>h", opts)
map("i", "<A-j>", "<C-\\><C-N><C-w>j", opts)
map("i", "<A-k>", "<C-\\><C-N><C-w>k", opts)
map("i", "<A-l>", "<C-\\><C-N><C-w>l", opts)
map("n", "<A-h>", "<C-w>h", opts)
map("n", "<A-j>", "<C-w>j", opts)
map("n", "<A-k>", "<C-w>k", opts)
map("n", "<A-l>", "<C-w>l", opts)
map('n', '<S-A-l>', ':vertical resize -4<CR>')
-- terminal stuff: http://neovim.io/doc/user/terminal.html#terminal
map('n', '<leader>tt', ':lcd %:p:h<CR>:terminal<CR>', opts) -- open terminal in dir of current file
map('n', '<leader>T', ':terminal<CR>', opts)                -- open terminal in working directory
map('t', '<S-Esc>', [[<C-\><C-n>]], opts)                   -- all other mappings didn't work
map('n', '<leader>tr', function()                           -- terminal in git root (if in git repo)
  local handle = io.popen('git rev-parse --is-inside-work-tree 2>/dev/null')
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then
      vim.cmd('lcd ' .. vim.fn.system('git rev-parse --show-toplevel'):gsub('\n', ''))
      vim.cmd('terminal')
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end, opts)

-- ====================================================================
-- lsp
-- ====================================================================

map("n", "gD", vim.lsp.buf.declaration, opts)
map("n", "gd", vim.lsp.buf.definition, opts)
map("n", "gi", vim.lsp.buf.implementation, opts)
map("n", "gs", vim.lsp.buf.signature_help, opts)
-- TODO see :help vim.lsp.buf<Tab>

-- ====================================================================
-- lspsaga https://nvimdev.github.io/lspsaga/
-- ====================================================================

map("n", "<leader>rn", ":Lspsaga rename <CR>", opts)
map("n", "<leader>rN", ":Lspsaga rename ++project<CR>", opts)
-- map("n", "<leader>RN", ":Lspsaga project_replace <CR>", d_opts)
map("n", "<leader>a", ":Lspsaga code_action<CR>", opts)

-- ====================================================================
-- diagnostic
-- ====================================================================

map("n", "[d", vim.diagnostic.goto_prev, opts)
map("n", "]d", vim.diagnostic.goto_next, opts)
map("n", "gef", vim.diagnostic.open_float, opts)
map("n", "geq", vim.diagnostic.setqflist, opts)

-- ====================================================================
-- oil
-- ====================================================================

map("n", "-", "<CMD>Oil<CR>", opts)

-- ====================================================================
-- telescope
-- ====================================================================

map("n", "<leader>ff", ":Telescope find_files hidden=true no_ignore=true<CR>", opts)
map("n", "<leader>fgf", ":Telescope git_files hidden=true no_ignore=true<CR>", opts)
map("n", "<leader>fgc", ":Telescope git_commits<CR>", opts)
map("n", "<leader>fgs", ":Telescope git_status<CR>", opts)
map("n", "<leader>fr", ":Telescope oldfiles<CR>", opts)
map("n", "<leader>fw", ":Telescope live_grep<CR>", opts)
map("n", "<leader>fW", ":Telescope live_grep word_match=-w<CR>", opts)
map("n", "<leader>fs", ":Telescope grep_string<CR>", opts)
map("n", "<leader>fb", ":Telescope buffers<CR>", opts)
map("n", "<leader>fh", ":Telescope help_tags<CR>", opts)
map("n", "<leader>fc", ":Telescope commands<CR>", opts)
map("n", "<leader>fk", ":Telescope keymaps<CR>", opts)
map("n", "gi", ":Telescope lsp_implementations<CR>", opts)
map("n", "gd", ":Telescope lsp_definitions<CR>", opts)
map("n", "gr", ":Telescope lsp_references<CR>", opts)
map("n", "gl", ":Telescope diagnostics<CR>", opts)
local builtin = require 'telescope.builtin'
local function fuzzy_find_current_buffer()
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end
map('n', '<leader>/', fuzzy_find_current_buffer, { desc = '[/] Fuzzily search in current buffer' })
map('n', '<C-f>', fuzzy_find_current_buffer, { desc = 'Fuzzily search in current buffer' })

