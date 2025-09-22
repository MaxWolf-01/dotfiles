return {
  -- Core DAP
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    config = function()
      -- Signs
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
    end,
  },

  -- Mason bridge for adapters (installs debugpy, etc.)
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = {
      ensure_installed = { "python" },
      automatic_installation = true,
      automatic_setup = false,
      handlers = {},
    },
    config = function(_, opts)
      require("mason-nvim-dap").setup(opts)
      -- Load our adapter/config after mason sets up providers to avoid overrides
      require("dap.python")
    end,
  },

  -- DAP UI
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      -- Open UI when the session is fully initialized
      dap.listeners.after.event_initialized.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },

  -- Inline virtual text for variables/stop reasons
  {
    "theHamsta/nvim-dap-virtual-text",
    opts = {
      commented = true,
      highlight_changed_variables = true,
      show_stop_reason = true,
      virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",
    },
  },

  -- Telescope integration
  {
    "nvim-telescope/telescope-dap.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("dap")
    end,
  },
}
