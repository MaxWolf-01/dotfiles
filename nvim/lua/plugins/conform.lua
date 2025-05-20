return {
  "stevearc/conform.nvim",

  event = "BufWritePre",

  opts = {
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  },

  config = function(opts)
    local formatters = {}

    local files = vim.api.nvim_get_runtime_file("lua/fmts/*.lua", true)
    for _, file in ipairs(files) do
      local fmt_name = file:match("([^/]+)%.%w+$")

      local mod = require("fmts." .. fmt_name)
      if mod ~= nil then
        formatters[fmt_name] = mod
      end
    end

    -- TODO: this is currently needeed?
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "*",
      callback = function(args)
        require("conform").format({ bufnr = args.buf })
      end,
    })

    opts.formatters_by_ft = formatters
    require("conform").setup(opts)
  end,
}
