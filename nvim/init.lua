vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Setup package manager
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    repo,
    "--branch=stable",
    lazypath,
  }
  if vim.v.shell_error ~= 0 then
    error("Error cloning lazy.nvim\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require "options"

require("lazy").setup("plugins", require "lazy")

vim.schedule(function()
  vim.filetype.add(require "filetypes")
  require "mappings"
end)

-- vim.cmd.colorscheme "catppuccin"

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Add the mason binary path to the PATH variable, so that plugins, such as
-- conform, can use the mason binaries.
local function configure_mason_path()
  local is_windows = vim.fn.has "win32" ~= 0
  local sep = is_windows and "\\" or "/"
  local delim = is_windows and ";" or ":"
  vim.env.PATH = table.concat({ vim.fn.stdpath "data", "mason", "bin" }, sep)
      .. delim
      .. vim.env.PATH
end
configure_mason_path()
