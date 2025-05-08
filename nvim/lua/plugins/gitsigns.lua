local signs = {
  add = { text = "" },
  change = { text = "" },
  delete = { text = "" },
  topdelete = { text = "" },
  changedelete = { text = "" },
  untracked = { text = "" },
}

return {
  "lewis6991/gitsigns.nvim",

  event = "BufRead",
  cmd = "Gitsigns",

  opts = {
    current_line_blame = true,
    signs = signs,
    signs_staged = signs,
  },
}
