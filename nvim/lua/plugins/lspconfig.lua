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

local function on_attach(_, _) end

local function on_init(client, _)
  if client.supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

local function get_capabilities()
  return require("cmp_nvim_lsp").default_capabilities()

  -- local capabilities = vim.lsp.protocol.make_client_capabilities()
  -- capabilities.textDocument.completion.completionItem = {
  --   documentationFormat = { "markdown", "plaintext" },
  --   snippetSupport = true,
  --   preselectSupport = true,
  --   insertReplaceSupport = true,
  --   labelDetailsSupport = true,
  --   deprecatedSupport = true,
  --   commitCharactersSupport = true,
  --   tagSupport = { valueSet = { 1 } },
  --   resolveSupport = {
  --     properties = {
  --       "documentation",
  --       "detail",
  --       "additionalTextEdits",
  --     },
  --   },
  -- }
  -- return capabilities
end

return {
  "neovim/nvim-lspconfig",
  config = function()
    local lsp_files = vim.api.nvim_get_runtime_file("lua/lsps/*.lua", true)
    for _, file in ipairs(lsp_files) do
      local lsp_name = file:match("([^/]+)%.%w+$")

      local opts = require("lsps." .. lsp_name)
      opts.capabilities = get_capabilities()

      local overriden_on_attach = opts.on_attach
      opts.on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        if overriden_on_attach then
          overriden_on_attach(client, bufnr)
        end
      end

      local overriden_on_init = opts.on_init
      opts.on_init = function(client, result)
        on_init(client, result)
        if overriden_on_init then
          overriden_on_init(client, result)
        end
      end

      require("lspconfig")[lsp_name].setup(require("lsps." .. lsp_name))
    end
  end,
}
