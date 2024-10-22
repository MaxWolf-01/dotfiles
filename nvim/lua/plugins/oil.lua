return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },

  event = "BufWinEnter",

  opts = {
    columns = {
      "icon",
      "permissions",
      "size",
    },
  },
}

