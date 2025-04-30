-- https://vimhelp.org/options.txt.html | :help vim.opt | :help option-list
-------------------

local o = vim.opt

-- Display and UI
--------------------
-- Line numbers
o.number = true         -- current line shows absolute line number
o.relativenumber = true -- other lines show relative line numbers
o.numberwidth = 2       -- number column width

-- Status information (disabled as handled by plugins)
o.ruler = false    -- don't show cursor position in status line
o.showmode = false -- don't show mode in command line

-- Visual indicators
o.signcolumn = "yes"       -- column to the left of numbers for git status, etc.
o.cursorline = true        -- highlight current line
o.cursorlineopt = "number" -- only highlight number of current line
o.showmatch = true         -- highlight matching brackets

-- Special character display
o.list = true
o.listchars = {
  tab = '» ',
  trail = '·',
  nbsp = '␣',
  extends = '›', -- when line is partially hidden due to no wrap
  precedes = '‹', -- when line is partially hidden due to no wrap
}

-- o.colorcolumn = "120"
-- highlight ColorColumn ctermbg=NONE guibg=NONE gui=undercurl guisp=#3b5f5f

-- Text Display and Wrapping
--------------------
o.wrap = false       -- don't wrap long lines by default
o.linebreak = true   -- when wrap is enabled, break at words
o.breakindent = true -- when a line wraps, maintain indentation level

-- Indentation and Tabs
--------------------
o.expandtab = true   -- use spaces instead of tabs
o.shiftwidth = 2     -- number of spaces for indentation
o.tabstop = 2        -- number of spaces a tab counts for
o.autoindent = true  -- copy indent from current line when starting a new line
o.smartindent = true -- do smart autoindenting when starting a new line

-- Window Management
--------------------
o.splitbelow = true -- place horizontal window splits below
o.splitright = true -- place vertical window splits right
o.scrolloff = 8     -- keep cursor this many lines from top/bottom when scrolling

-- Search and Replace
--------------------
o.ignorecase = true    -- case-insensitive searching
o.smartcase = true     -- unless search contains uppercase letters
o.hlsearch = true      -- highlight all matches of search pattern
o.incsearch = true     -- show matches as you type
o.inccommand = 'split' -- live preview substitutions

-- Editing Experience
--------------------
o.mouse = "a"      -- enable mouse mode
o.timeoutlen = 300 -- time to wait for a mapped sequence to complete
o.updatetime = 250 -- time before triggering certain events (e.g. hover docs)
o.undofile = true  -- persistent undo history
o.confirm = true   -- ask for confirmation instead of failing due to unsaved changes
-- Sync clipboard between OS and Neovim. See `:help 'clipboard'`
--  Schedule the setting after `UiEnter` because it can increase startup-time.
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)
