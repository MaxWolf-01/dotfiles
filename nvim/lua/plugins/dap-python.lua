return {
  "mfussenegger/nvim-dap-python",
  dependencies = { "mfussenegger/nvim-dap" },
  ft = { "python" },
  config = function()
    local venv = vim.env.VIRTUAL_ENV
    local interpreter = "uv"
    if venv and venv ~= "" and vim.fn.executable(venv .. "/bin/python") == 1 then
      interpreter = venv .. "/bin/python"
    end
    require("dap-python").setup(interpreter)
    -- Optional: tune test runner here if you use pytest/unittest
    -- require("dap-python").test_runner = "pytest"
  end,
}
