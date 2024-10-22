return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },

  cmd = "Telescope",

  opts = {
    defaults = {
      theme = "dropdown",
      prompt_prefix = "   ",
      selection_caret = " ",
      entry_prefix = " ",
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
        },
        width = 0.87,
        height = 0.80,
      },
      mappings = {
        n = { ["q"] = require("telescope.actions").close },
      },
    },
  },
}

