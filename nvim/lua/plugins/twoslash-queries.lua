return {
  "marilari88/twoslash-queries.nvim",
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  config = function()
    require("twoslash-queries").setup{}  -- or pass your opts here
  end,
}

