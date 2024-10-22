return {
  {
    "nvim-treesitter/nvim-treesitter",

    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },

    opts = {
      ensure_installed = { "lua", "luadoc", "printf", "vim", "vimdoc" },

      highlight = {
        enable = true,
        use_languagetree = true,
      },

      indent = {
        enable = true,
      },
    },

    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  {
    "IndianBoy42/tree-sitter-just",
    dependencies = { "nvim-treesitter/nvim-treesitter" },

    opts = {},
  },
}

