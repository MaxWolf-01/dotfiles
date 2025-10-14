-- Multi-cursor editing
-- https://github.com/mg979/vim-visual-multi
return {
  "mg979/vim-visual-multi",
  branch = "master",
  event = "VeryLazy",
  init = function()
    -- Use Ctrl-n to start multi-cursor on current word
    -- Keep pressing Ctrl-n to add more matches
    -- Ctrl-x to skip current and go to next
    -- Ctrl-p to remove current and go back to previous
    --
    -- In multi-cursor mode:
    --   i, a, I, A - insert/append modes
    --   c - change (works with motions: ciw, ci", etc.)
    --   d - delete (works with motions)
    --   y - yank
    --   p - paste
    --   ~ - toggle case
    --   / - search within selected regions
    --   Tab - Switch Mode (toggles Cursor <-> Extend)
    --        Cursor: motions move cursors; Extend: motions resize regions (like visual)
    --   Esc or Ctrl-c - exit multi-cursor
    --
    -- Visual mode multi-cursor:
    --   Select text with v/V, then Ctrl-n to add more matches
    --   \\A to select all occurrences
    --   \\/ to regex search and create cursors
    --   \\  to add a cursor at the current position (repeat at other positions)
    --
    -- Terminology:
    --   A "region" is one selected occurrence managed by visual-multi
    --   (start/end + cursor). Actions like skip/remove operate per-region.
    --
    -- Column editing (like Ctrl-v but better):
    --   Ctrl-Down/Ctrl-Up to add cursors vertically
    --   \\c to create column of cursors in visual selection

    -- Disable default mappings to avoid conflicts
    vim.g.VM_default_mappings = 0

    -- Custom mappings (you can adjust these)
    vim.g.VM_maps = {
      ["Find Under"] = "<C-n>", -- Start/add selection
      ["Find Subword Under"] = "<C-n>",
      ["Skip Region"] = "<C-x>", -- Skip current match
      ["Remove Region"] = "<C-p>", -- Remove current and go back
      ["Add Cursor Down"] = "<C-Down>", -- Add cursor below
      ["Add Cursor Up"] = "<C-Up>", -- Add cursor above
      ["Switch Mode"] = "<Tab>", -- Toggle Cursor/Extend mode
      ["Select All"] = "\\\\A", -- Select all occurrences ("\\A")
      ["Start Regex Search"] = "\\\\/", -- Regex search ("\\/")
      ["Add Cursor At Pos"] = "\\", -- Add cursor at position ("\\")
      ["Reselect Last"] = "\\\\r", -- Reselect last pattern/regions ("\\r")
      ["Goto Next"] = "\\\\]", -- Jump to next region ("\\]")
      ["Goto Prev"] = "\\\\[", -- Jump to previous region ("\\[")
      ["Visual Cursors"] = "\\\\c", -- Column cursors in visual
      ["Undo"] = "u",
      ["Redo"] = "<C-r>",
    }

    -- Mouse support: Ctrl-LeftClick adds a cursor at click position.
    -- Implemented by translating the click into your existing "Add Cursor At Pos" mapping ("\\").
    -- Safe: only triggers VM action, no global conflicts found.
    vim.keymap.set("n", "<C-LeftMouse>", [[<LeftMouse>\]], { remap = true, silent = true, desc = "VM: Add cursor at click" })

    -- Theme (integrates with your colorscheme)
    vim.g.VM_theme = "iceblue"

    -- Show messages about multi-cursor state
    vim.g.VM_verbose_commands = 1

    -- Highlight settings (you can customize colors)
    vim.g.VM_highlight_matches = "underline"
  end,
}
