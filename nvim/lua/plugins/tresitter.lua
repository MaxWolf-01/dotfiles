return {
  {
    "nvim-treesitter/nvim-treesitter",

    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },

    opts = {
      ensure_installed = { "just", "lua", "luadoc", "printf", "vim", "vimdoc" },
    },

    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
    end,
  },

}

