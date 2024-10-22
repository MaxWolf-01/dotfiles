return {
  settings = {
    gopls = {
      completeUnimported = true,
      usePlaceholders = true,
      analyses = {
        unusedparams = true,
      },
    },
    env = {
      GOEXPERIMENT = "rangefunc",
    },
  },
}
