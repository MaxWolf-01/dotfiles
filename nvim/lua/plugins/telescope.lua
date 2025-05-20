return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }, },

  cmd = "Telescope",

  opts = {
    defaults = {
      theme = "dropdown",
      prompt_prefix = "  ",
      selection_caret = " ",
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
        n = {
          ["q"] = require("telescope.actions").close,
          ["H"] = "preview_scrolling_left",
          ["L"] = "preview_scrolling_right",
        },
        i = {
          ["<C-j>"] = "move_selection_next",
          ["<C-k>"] = "move_selection_previous",
          ["<C-n>"] = "move_selection_next",
          ["<C-p>"] = "move_selection_previous",

          ["<C-c>"] = "close",

          ["<C-h>"] = "which_key",
        },
      },
    },
    extensions = {
      fzf = {
        fuzzy                   = true,
        override_generic_sorter = false,
        override_file_sorter    = true,
        case_mode               = "smart_case",
      },
    },
  },
  config = function(_, opts)
    require("telescope").setup(opts)
    require("telescope").load_extension("fzf")
  end,
}
