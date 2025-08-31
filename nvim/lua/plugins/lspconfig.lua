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
  return require("blink.cmp").get_lsp_capabilities()

  -- Note: blink.cmp's get_lsp_capabilities() already includes the default capabilities
  -- and adds completion-specific capabilities automatically
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
