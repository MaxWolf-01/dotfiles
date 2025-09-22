---@diagnostic disable: undefined-global
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
    texthl = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
      [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
      [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
      [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
    },
  },
})

return {
  "neovim/nvim-lspconfig",
  config = function()
    local caps = require("blink.cmp").get_lsp_capabilities()
    local function on_attach(_, _) end
    local function on_init(client, _)
      if client.supports_method("textDocument/semanticTokens") then
        client.server_capabilities.semanticTokensProvider = nil
      end
    end

    -- Enable servers via the 0.11 API; upstream configs live under runtime lsp/<name>.lua
    local servers = {
      "bashls",
      "biome",
      "cmake",
      "docker_compose_language_service",
      "dockerls",
      "elixirls",
      "gleam",
      "golangci_lint_ls",
      "gopls",
      "hls",
      "html",
      "jdtls",
      "jsonls",
      "lua_ls",
      "nil_ls",
      "nixd",
      "pyright",
      "rust_analyzer",
      "tailwindcss",
      "taplo",
      "ts_ls",
      "zls",
    }

    for _, s in ipairs(servers) do
      vim.lsp.enable(s, {
        capabilities = caps,
        on_attach = on_attach,
        on_init = on_init,
      })
    end
  end,
}
