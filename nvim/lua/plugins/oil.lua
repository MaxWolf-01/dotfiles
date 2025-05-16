return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },

  event = "BufWinEnter",

  opts = {
    view_options = {
      show_hidden = true,
    },
    columns = {
      "icon",
      "permissions",
      "size",
    },
  },
}
