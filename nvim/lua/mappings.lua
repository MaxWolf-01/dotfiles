local map = vim.keymap.set
local opts = {    -- default options
  noremap = true, -- non-recursive, i.e. ignore other mappings; true per default
  silent = true,  -- prevents command from being echoed in the command line
}

-- ====================================================================
-- basic
-- ====================================================================

map("n", "<leader>d", ":Dashboard<CR>", opts)            -- show dashboard
map("n", "U", "<NOP>", opts)                             -- disable U (scary behvaior)
-- Scroling and finding
map("n", "<C-d>", "<C-d>zz", opts)                       -- centered cursor when scrolling down
map("n", "<C-u>", "<C-u>zz", opts)                       -- centered cursor when scrolling up
map('n', 'n', 'nzzzv')                                   -- Next search result stays centered
map('n', 'N', 'Nzzzv')                                   -- Previous search result stays centered
-- Saving and quitting
map("n", "<C-s>", ":w<CR>", opts)                        -- ctrl+s saves in normal ...
map("i", "<C-s>", "<Esc>:w<CR>a", opts)                  -- ... and in insert mode returns to insert
map('n', '<leader>w', ':w<CR>')                          -- Save with space+w
map('n', '<leader>q', ':q<CR>')                          -- Quit with space+q
map("x", "<leader>p", "\"_dP", opts)                     -- preserve paste register when pasting over selection
-- Directory Navigation
map('n', '<leader>cd', ':cd %:p:h<CR>:pwd<CR>')          -- cd to dir of current file and show it
map('n', '<leader>cdww', ':lcd %:p:h<CR>:pwd<CR>', opts) -- window-local cd to dir of current file and show it
map('n', '<leader>cdr', function()                       -- cd to git root of current file (if in git repo)
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
end, opts)
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
end, opts)


-- terminal stuff
map('n', '<leader>tt', ':lcd %:p:h<CR>:terminal<CR>', opts) -- open terminal in dir of current file
map('n', '<leader>T', ':terminal<CR>', opts)                -- open terminal in working directory
map('t', '<S-Esc>', '<C-\\><C-n>', opts)                    -- all other mappings didn't work
-- vim.keymap.set('t', 'jk', '<C-\\><C-n>', { noremap = true })
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

map("n", "<leader>ff", ":Telescope find_files<CR>", opts)
map("n", "<leader>fw", ":Telescope live_grep<CR>", opts)
map("n", "<leader>fb", ":Telescope buffers<CR>", opts)
map("n", "gi", ":Telescope lsp_implementations<CR>", opts)
map("n", "gd", ":Telescope lsp_definitions<CR>", opts)
map("n", "gr", ":Telescope lsp_references<CR>", opts)
map("n", "gl", ":Telescope diagnostics<CR>", opts)

-- https://github.com/lukasl-dev/nixos/blob/master/dots/nvim/lua/mappings.lua
