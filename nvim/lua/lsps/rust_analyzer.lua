return {
  settings = {
    ["rust-analyzer"] = {
      check = {
        command = "clippy",
      },
      diagnostics = {
        enable = true,
      },
      cargo = {
        buildScripts = {
          enable = true,
        },
      },
    },
  },
  on_attach = function(_, bufnr)
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end,
}
