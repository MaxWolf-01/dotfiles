-- Molten: run Jupyter kernels directly from nvim (ZMQ, no browser/selenium).
-- Outputs render as virtual text in the buffer (works inside tmux). Images are
-- off (image.nvim + a graphics terminal outside tmux would be needed); plots are
-- saved to disk by the code anyway.
-- Kernel `pip2` (the project venv, has torch) is registered via:
--   uv run python -m ipykernel install --user --name pip2
return {
  "benlubas/molten-nvim",
  version = "^1.0.0",
  build = ":UpdateRemotePlugins",
  ft = "python",
  init = function()
    -- python3 host is configured in options.lua (nix wrapper disables it)
    vim.g.molten_image_provider = "none"
    vim.g.molten_virt_text_output = true   -- show output inline as virtual text
    vim.g.molten_virt_lines_off_by_1 = true
    vim.g.molten_wrap_output = true
    vim.g.molten_auto_open_output = false   -- don't steal focus; virt text shows it
    vim.g.molten_output_win_max_height = 20
    vim.g.molten_enter_output_behavior = "open_and_enter"  -- <leader>mO enters in one press (scrollable)
  end,
  keys = {
    { "<leader>mi", ":MoltenInit pip2<CR>", desc = "Molten init (pip2 kernel)" },
    {
      "<leader>mr",
      function()
        -- run the current `# %%` cell (markers delimit cells, jupytext percent format)
        local start = vim.fn.search("^# %%", "bcnW")
        start = (start == 0) and 1 or start + 1
        local nxt = vim.fn.search("^# %%", "nW")
        local finish = (nxt == 0) and vim.fn.line("$") or (nxt - 1)
        vim.fn.MoltenEvaluateRange(start, finish)
      end,
      desc = "Molten run cell (# %%)",
    },
    {
      "<leader>mR",
      function()
        -- run every `# %%` code cell top to bottom (skips [markdown] cells).
        -- run `:MoltenInit pip2` first; afterwards `:MoltenReevaluateAll` re-runs them.
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local starts = {}
        for i, l in ipairs(lines) do
          if l:match("^# %%%%") then
            table.insert(starts, { line = i, md = l:match("%[markdown%]") ~= nil })
          end
        end
        for idx, cell in ipairs(starts) do
          local body_start = cell.line + 1
          local body_end = starts[idx + 1] and (starts[idx + 1].line - 1) or #lines
          if not cell.md and body_start <= body_end then
            vim.fn.MoltenEvaluateRange(body_start, body_end)
          end
        end
      end,
      desc = "Molten run all cells",
    },
    { "<leader>ml", ":MoltenEvaluateLine<CR>", desc = "Molten eval line" },
    { "<leader>me", ":MoltenEvaluateOperator<CR>", desc = "Molten eval operator" },
    { "<leader>mc", ":MoltenReevaluateCell<CR>", desc = "Molten re-eval cell" },
    { "<leader>mv", ":<C-u>MoltenEvaluateVisual<CR>gv", mode = "x", desc = "Molten eval selection" },
    { "<leader>mo", ":MoltenShowOutput<CR>", desc = "Molten show output" },
    { "<leader>mO", ":noautocmd MoltenEnterOutput<CR>", desc = "Molten enter output window" },
    { "<leader>mh", ":MoltenHideOutput<CR>", desc = "Molten hide output" },
    { "<leader>md", ":MoltenDelete<CR>", desc = "Molten delete cell" },
  },
}
