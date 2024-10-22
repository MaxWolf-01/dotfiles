return {
  init_options = {
    preferences = {
      importModuleSpecifierPreference = "non-relative",
    },
  },

  on_attach = function(client, bufnr)
    require("twoslash-queries").attach(client, bufnr)
  end,
}
