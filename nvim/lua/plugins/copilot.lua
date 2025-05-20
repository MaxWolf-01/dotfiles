return {
  "github/copilot.vim",
  config = function()
    -- we'll handle all mappings ourselves
    vim.g.copilot_no_tab_map    = true
    vim.g.copilot_assume_mapped = true
    -- request a suggestion
    vim.keymap.set("i", "<A-q>",
      "copilot#Suggest()",
      { expr = true, silent = true, replace_keycodes = false }
    )
    -- accept current suggestion
    vim.keymap.set("i", "<A-w>",
      'copilot#Accept("")',
      { expr = true, silent = true, replace_keycodes = false }
    )
    vim.keymap.set("i", "<A-e>", "copilot#Dismiss()", { expr = true, silent = true })
    vim.keymap.set("i", "<A-d>", "copilot#Next()", { expr = true, silent = true })
    vim.keymap.set("i", "<A-a>", "copilot#Previous()", { expr = true, silent = true })
    -- toggle Copilot on/off (uses buffer-scoped flag set by the plugin)
    vim.keymap.set("n", "<leader>cc", function()
      if vim.b.copilot_suggestion_enabled then
        vim.cmd("Copilot disable")
      else
        vim.cmd("Copilot enable")
      end
    end, { silent = true, desc = "Toggle Copilot" })
  end,
}
