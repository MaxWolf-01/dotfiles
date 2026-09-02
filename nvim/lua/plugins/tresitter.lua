return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",

    config = function()
      require("nvim-treesitter").install({
        "bash", "c", "c_sharp", "cpp", "css", "dockerfile", "go", "html",
        "javascript", "json", "just", "nix", "python", "rust", "toml",
        "typescript", "yaml",
      })
      -- start() errors when no parser exists for the filetype; pcall makes
      -- that the silent regex fallback instead of a message on every buffer
      vim.api.nvim_create_autocmd("FileType", {
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
  },
}
