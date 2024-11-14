return {
  "nvimdev/lspsaga.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },

  event = "LspAttach",

  opts = {
    ui = {
      --      kind = require("catppuccin.groups.integrations.lsp_saga").custom_kind(),
    },
    symbol_in_winbar = {
      enable = true,
    },
    lightbulb = {
      enable = true,
    },
  },
}
