local function is_available(bufnr, formatter)
  return require("conform").get_formatter_info(formatter, bufnr).available
end

local function javascript(bufnr)
  if is_available(bufnr, "biome") then
    return { "biome" }
  end
  return { "prettier", "eslint" }
end

return {
  "stevearc/conform.nvim",

  event = "BufWritePre",

  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      go = function(bufnr)
        if is_available(bufnr, "gofumpt") then
          return { "goimports", "gofumpt" }
        end
        return { "goimports", "gofmt" }
      end,
      markdown = { "mdformat" },
      python = function(bufnr)
        if is_available(bufnr, "ruff_format") then
          return { "ruff_format" }
        end
        return { "isort", "black" }
      end,
      typescript = javascript,
      typescriptreact = javascript,
      javascript = javascript,
      javascriptreact = javascript,
      zig = { "zigfmt" },
      nix = { "nixfmt" },
      just = { "just" },
      rust = { "rustfmt", lsp_format = "fallback" },
    },

    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  },
}

