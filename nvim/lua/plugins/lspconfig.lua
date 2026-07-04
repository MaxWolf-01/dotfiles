---@diagnostic disable: undefined-global
vim.diagnostic.config({
  -- sign column symbols and highlights
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
  -- inline virtual text to the right of the line
  virtual_text = {
    spacing = 1,
    source = "if_many",
    -- prefix = "●", -- uncomment to force a bullet prefix
  },
  -- underline the offending range
  underline = true,
  -- nicer sorting/behavior
  severity_sort = true,
  update_in_insert = false,
  float = {
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

return {
  "neovim/nvim-lspconfig",
  config = function()
    vim.lsp.config('*', {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
      on_init = function(client)
        if client:supports_method("textDocument/semanticTokens") then
          client.server_capabilities.semanticTokensProvider = nil
        end
      end,
    })

    local servers = {
      "bashls",
      "biome",
      "cmake",
      "copilot",
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
      "markdown_oxide",
      "nil_ls",
      "nixd",
      "ty",
      "rust_analyzer",
      "tailwindcss",
      "taplo",
      "ts_ls",
      "zls",
    }

    -- register overrides via vim.lsp.config(), which takes precedence over ALL
    -- lsp/*.lua rtp files -- nvim merges those in rtp order with later (i.e.
    -- nvim-lspconfig's) files winning, so user lsp/*.lua files can't override
    for _, name in ipairs(servers) do
      local ok, cfg = pcall(require, "lsps." .. name)
      if ok then
        vim.lsp.config(name, cfg)
      elseif not tostring(cfg):match("module 'lsps%.") then
        vim.notify(("lsps.%s failed to load: %s"):format(name, cfg), vim.log.levels.ERROR)
      end
    end

    vim.lsp.enable(servers)
  end,
}
