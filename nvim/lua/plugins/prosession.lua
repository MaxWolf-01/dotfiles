return {
  {
    "dhruvasagar/vim-prosession",
    dependencies = { "tpope/vim-obsession", "nvim-telescope/telescope.nvim" },
    lazy = false,
    init = function()
      vim.g.prosession_on_startup = 1 -- auto-attach if nvim starts with no args
      vim.g.prosession_per_branch = 0 -- separate session per git branch
      vim.g.prosession_tmux_title = 1 -- update tmux window title
    end,

    config = function()
      require("telescope").load_extension("prosession")
    end,
  },
}
