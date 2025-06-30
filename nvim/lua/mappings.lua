-- TODO restructure with claude, add comments as descriptions

local map = vim.keymap.set
local opts = { -- default options
  noremap = true, -- non-recursive, i.e. ignore other mappings; true per default
  silent = true, -- prevents command from being echoed in the command line
}

-- ====================================================================
-- basic
-- ====================================================================

map("i", "<C-c>", "<Esc>", opts) -- ctrl+c with the same behavior as <Esc>
map("n", "<leader><leader>", ":Dashboard<CR>", opts) -- show dashboard: https://github.com/nvimdev/dashboard-nvim
map("n", "U", "<NOP>", opts) -- disable U (scary behvaior)
map("n", "<leader>y", ":%y<CR>", opts) -- copy all
map("n", "<Esc>", "<cmd>nohlsearch<CR>") -- Clear highlights on search when pressing <Esc> in normal mode. See `:help hlsearch`
map("x", "<leader>p", '"_dP', opts) -- preserve paste register when pasting over selection

-- Code blocks

map("n", "dic", "V?```<CR>jo/```<CR>kd", { desc = "Delete inside code block" })
map("n", "dac", "V?```<CR>o/```<CR>d", { desc = "Delete around code block" })
map("n", "yic", "V?```<CR>jo/```<CR>ky", { desc = "Yank inside code block" })
map("n", "yac", "V?```<CR>o/```<CR>y", { desc = "Yank around code block" })
map("n", "cic", "V?```<CR>jo/```<CR>kc", { desc = "Change inside code block" })
map("n", "cac", "V?```<CR>o/```<CR>c", { desc = "Change around code block" })
map("n", "gcic", "V?```<CR>jo/```<CR>kgc", { desc = "Comment inside code block" })
map("n", "gcac", "V?```<CR>o/```<CR>gc", { desc = "Comment around code block" })

-- Scroling and finding

map("n", "<C-d>", "<C-d>zz", opts) -- centered cursor when scrolling down
map("n", "<C-u>", "<C-u>zz", opts) -- centered cursor when scrolling up
map("n", "n", "nzzzv", opts) -- next search result stays centered
map("n", "N", "Nzzzv", opts) -- previous search result stays centered

-- Saving and quitting

map("n", "<C-s>", ":w<CR>", opts) -- ctrl+s saves in normal ...
map("i", "<C-s>", "<Esc>:w<CR>a", opts) -- ... and in insert mode returns to insert
map("n", "<leader>ww", ":w<CR>", opts)
map("n", "<leader>wqq", ":wq<CR>", opts)
map("n", "<leader>wa", ":wa<CR>", opts)
map("n", "<leader>wx", ":wqa<CR>", opts)
map("n", "<leader>qa", ":qa<CR>", opts)
map("n", "<leader>qq", ":q<CR>", opts)

-- Directory Navigation

map("n", "<leader>cd", ":cd %:p:h<CR>:pwd<CR>") -- cd to dir of current file and show it
map("n", "<leader>cdww", ":lcd %:p:h<CR>:pwd<CR>") -- window-local cd to dir of current file and show it
map("n", "<leader>cdr", function() -- cd to git root of current file (if in git repo)
  local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then -- If in git repo
      vim.cmd("cd " .. vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", ""))
      vim.cmd("pwd")
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end)

map("n", "<leader>cdwr", function() -- window-local cd to git root of current file (if in git repo)
  local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then -- If in git repo
      vim.cmd("lcd " .. vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", ""))
      vim.cmd("pwd")
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end)

-- window splits

map("n", "<leader>vv", ":vsplit<CR>", opts)
map("n", "<leader>vh", ":split<CR>", opts)

-- window resizing

map("n", "<S-A-h>", ":vertical resize +4<CR>", opts)
map("n", "<S-A-l>", ":vertical resize -4<CR>") -- decrease width
map("n", "<S-A-j>", ":resize -4<CR>", opts)
map("n", "<S-A-k>", ":resize +4<CR>", opts)

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
map("n", "<S-A-l>", ":vertical resize -4<CR>")

-- terminal stuff: http://neovim.io/doc/user/terminal.html#terminal

map("n", "<leader>tt", ":lcd %:p:h<CR>:terminal<CR>", opts) -- open terminal in dir of current file
map("n", "<leader>T", ":terminal<CR>", opts) -- open terminal in working directory
map("t", "<S-Esc>", [[<C-\><C-n>]], opts) -- all other mappings didn't work
map("n", "<leader>tr", function() -- terminal in git root (if in git repo)
  local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result ~= "" then
      vim.cmd("lcd " .. vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", ""))
      vim.cmd("terminal")
    else
      vim.notify("Not in a git repository", vim.log.levels.WARN)
    end
  end
end, opts)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ====================================================================
-- lsp
-- ====================================================================

-- navigation

map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
map("n", "gt", vim.lsp.buf.type_definition, { desc = "Go to type definition" })

-- information

map("n", "Q", vim.lsp.buf.hover, { desc = "Show over documentation" })
map("n", "<C-q>", vim.lsp.buf.signature_help, { desc = "Show signature help" })

-- actions

map("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code actions" })
map("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>lf", vim.lsp.buf.format, { desc = "Format document" })

-- diagnostics

map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true }) end, { desc = "Previous error" })
map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true }) end, { desc = "Next error" })
map("n", "[w", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN, float = true }) end, { desc = "Previous warning" })
map("n", "]w", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN, float = true }) end, { desc = "Next warning" })

map("n", "<leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
map("n", "<leader>lQ", vim.diagnostic.setqflist, { desc = "Diagnostics to quickfix" })

-- ====================================================================
-- lspsaga https://nvimdev.github.io/lspsaga/
-- ====================================================================

-- TODO
-- map("n", "<leader>lR", ":Lspsaga rename ++project<CR>", { desc = "Rename across project", silent = true })
-- map("n", "<leader>la", ":Lspsaga code_action<CR>", { desc = "Code actions (saga)", silent = true })
-- map("n", "<leader>lo", ":Lspsaga outline<CR>", { desc = "Show document outline", silent = true })

-- ====================================================================
-- oil
-- ====================================================================

map("n", "-", "<CMD>Oil<CR>", opts)

-- ====================================================================
-- telescope
-- ====================================================================

map("n", "<leader>ff", ":Telescope git_files hidden=true show_untracked=true<CR>", opts)
map("n", "<leader>fg", ":Telescope git_files hidden=true<CR>", opts)
map("n", "<leader>fa", ":Telescope find_files hidden=false no_ignore=true<CR>", opts)
map("n", "<leader>ft", ":Telescope oldfiles<CR>", opts)
map("n", "<leader>fb", ":Telescope buffers<CR>", opts)

map("n", "<leader>fw", ":Telescope live_grep hidden=true<CR>", opts) -- TODO!! It does not search in hidden files!
map("n", "<leader>fW", ":Telescope live_grep word_match=-w<CR>", opts)
map("n", "<leader>fl", ":Telescope grep_string<CR>", opts) -- literal search (no regex)
local builtin = require("telescope.builtin")
local function fuzzy_find_current_buffer()
  builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end
map("n", "<leader>/", fuzzy_find_current_buffer, { desc = "[/] Fuzzily search in current buffer" })
map("n", "<C-f>", fuzzy_find_current_buffer, { desc = "Fuzzily search in current buffer" })

map("n", "<leader>fc", ":Telescope commands<CR>", opts)

map("n", "<leader>fd", ":Telescope lsp_definitions<CR>", opts)
map("n", "<leader>fD", ":Telescope lsp_type_definitions<CR>", opts)
map("n", "<leader>fr", ":Telescope lsp_references<CR>", opts)
map("n", "<leader>fi", ":Telescope lsp_implementations<CR>", opts)
map("n", "<leader>fx", ":Telescope diagnostics<CR>", opts)

map("n", "<leader>fs", ":Telescope prosession<CR>", { desc = "Find / switch session", silent = true })

map("n", "<leader>fh", ":Telescope help_tags<CR>", opts)
map("n", "<leader>fk", ":Telescope keymaps<CR>", opts)

map("n", "<leader>gc", ":Telescope git_commits<CR>", opts)
map("n", "<leader>gfh", ":Telescope git_bcommits<CR>", opts)
map("n", "<leader>gst", ":Telescope git_status<CR>", opts)
map("n", "<leader>gbr", ":Telescope git_branches<CR>", opts)

-- ====================================================================
-- git
-- ====================================================================

-- https://github.com/lewis6991/gitsigns.nvim
map("n", "<leader>gh", ":Gitsigns preview_hunk<CR>", { desc = "Preview hunk", silent = true })
map("n", "<leader>gs", ":Gitsigns stage_hunk<CR>", { desc = "Stage hunk", silent = true })
map("n", "<leader>gS", ":Gitsigns stage_buffer<CR>", { desc = "Stage buffer", silent = true })
map("n", "<leader>gr", ":Gitsigns reset_hunk<CR>", { desc = "Reset hunk", silent = true })
map("n", "<leader>gu", ":Gitsigns undo_stage_hunk<CR>", { desc = "Undo stage hunk", silent = true })
map("n", "<leader>gR", ":Gitsigns reset_buffer<CR>", { desc = "Reset buffer", silent = true })
map("n", "[h", ":Gitsigns prev_hunk<CR>", { desc = "Previous hunk", silent = true })
map("n", "]h", ":Gitsigns next_hunk<CR>", { desc = "Next hunk", silent = true })
map("n", "<leader>gtd", ":Gitsigns toggle_deleted<CR>", { desc = "Toggle deleted", silent = true })
-- TODO replace with hunk.nvim?
map("n", "<leader>gd", ":Gitsigns diffthis<CR>", { desc = "Diff this", silent = true })
map("n", "<leader>gD", ":Gitsigns diffthis HEAD<CR>", { desc = "Diff with HEAD", silent = true })

-- TODO fugitive.vim for blaming entire buffer, ...

-- ====================================================================
-- Sessions
-- ====================================================================

-- https://github.com/dhruvasagar/vim-prosession
map("n", "<leader>sd", ":ProsessionDelete<CR>", { desc = "Delete current session", silent = true })
map("n", "<leader>sc", ":ProsessionClean<CR>", { desc = "Clean stale session files", silent = true })
