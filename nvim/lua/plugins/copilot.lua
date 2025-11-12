return {
  "github/copilot.vim",
  config = function()

    -- we'll handle all mappings ourselves
    vim.g.copilot_no_tab_map    = true
    vim.g.copilot_assume_mapped = true

    -- request a suggestion
    vim.keymap.set("i", "<A-r>",
      "copilot#Suggest()",
      { expr = true, silent = true, replace_keycodes = false }
    )

    -- accept next word 
    vim.keymap.set("i", "<A-w>",
      'copilot#AcceptWord()',
      { expr = true, silent = true, replace_keycodes = false }
    )

    -- accept next line
    vim.keymap.set("i", "<A-q>",
      'copilot#AcceptLine()',
      { expr = true, silent = true, replace_keycodes = false }
    )

    -- accept current suggestion
    vim.keymap.set("i", "<A-s>",
      'copilot#Accept("")',
      { expr = true, silent = true, replace_keycodes = false }
    )
    vim.keymap.set("i", "<A-e>", "copilot#Dismiss()", { expr = true, silent = true })
    vim.keymap.set("i", "<A-d>", "copilot#Next()", { expr = true, silent = true })
    vim.keymap.set("i", "<A-a>", "copilot#Previous()", { expr = true, silent = true })

    -- toggle Copilot on/off
    vim.keymap.set("n", "<leader>cc", function()
      if vim.b.copilot_enabled == 0 then
        vim.cmd("Copilot enable")
        vim.notify("Copilot enabled", vim.log.levels.INFO)
      else
        vim.cmd("Copilot disable")
        vim.notify("Copilot disabled", vim.log.levels.INFO)
      end
    end, { silent = true, desc = "Toggle Copilot" })

  end,
}
