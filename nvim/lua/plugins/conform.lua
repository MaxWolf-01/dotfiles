return {
  "stevearc/conform.nvim",

  event = { "BufReadPre", "BufNewFile" },
  cmd = { "ConformInfo" },

  init = function()
    -- Initialize global autoformat to false (disabled by default)
    -- This runs before setup, ensuring the variable exists
    vim.g.autoformat = vim.g.autoformat or false
  end,

  config = function()
    local formatters = {}

    local files = vim.api.nvim_get_runtime_file("lua/fmts/*.lua", true)
    for _, file in ipairs(files) do
      local fmt_name = file:match("([^/]+)%.%w+$")

      local mod = require("fmts." .. fmt_name)
      if mod ~= nil then
        formatters[fmt_name] = mod
      end
    end

    -- Setup conform with our config
    require("conform").setup({
      -- Always use uvx-backed ruff for consistency with your environment
      formatters = {
        -- Use ruff as a formatter (stdout)
        ruff_format = {
          command = "uvx",
          args = { "ruff", "format", "--stdin-filename", "$FILENAME", "-" },
          stdin = true,
        },
        -- Use ruff to apply fixes (imports) to a temp file, then read back
        -- ruff cannot apply fixes via stdin; it needs a filename
        ruff_fix = {
          command = "uvx",
          args = { "ruff", "check", "--fix", "--select", "I", "--exit-zero", "--quiet", "$FILENAME" },
          stdin = false,
          require_tempfile = true,
        },
      },
      formatters_by_ft = formatters,
      
      -- Dynamic format_on_save that checks toggle state
      format_on_save = function(bufnr)
        -- Check buffer-local override first
        if vim.b[bufnr].autoformat_disabled then
          return nil
        end
        -- Then check global setting (default is false)
        if not vim.g.autoformat then
          return nil
        end
        -- Format with timeout and LSP fallback
        return {
          timeout_ms = 500,
          lsp_fallback = true,
        }
      end,
    })
  end,
}
