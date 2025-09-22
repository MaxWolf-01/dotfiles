local dap = require("dap")

dap.configurations.python = {
  -- Launch configurations are provided by nvim-dap-python; we only add attaches here
  {
    type = "python",
    request = "attach",
    name = "Attach to debugpy",
    connect = function()
      local host = vim.fn.input("Host [127.0.0.1]: ")
      local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
      return { host = host ~= "" and host or "127.0.0.1", port = port }
    end,
    -- Local attach: no pathMappings to avoid breakpoint rejection
  },
  {
    type = "python",
    request = "attach",
    name = "Attach (localhost:5678)",
    connect = { host = "127.0.0.1", port = 5678 },
    -- Local attach: no pathMappings to avoid breakpoint rejection
  },
}
