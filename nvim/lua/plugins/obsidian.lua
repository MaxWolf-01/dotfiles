return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  lazy = true,
  event = {
    "BufReadPre " .. vim.fn.expand("~") .. "/repos/obsidian/knowledge-base/**.md",
    "BufNewFile " .. vim.fn.expand("~") .. "/repos/obsidian/knowledge-base/**.md",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    legacy_commands = false,

    workspaces = {
      {
        name = "knowledge-base",
        path = "~/repos/obsidian/knowledge-base",
      },
    },

    notes_subdir = "general",
    new_notes_location = "notes_subdir",

    -- Use the note title as filename, not zettel IDs
    note_id_func = function(title)
      if title then
        return title
      end
      return tostring(os.time())
    end,

    daily_notes = {
      folder = "Obsidian/daily-notes",
      date_format = "YYYY-MM-DD",
      template = "daily",
    },

    templates = {
      folder = "Obsidian/templates",
      date_format = "YYYY-MM-DD",
      time_format = "HH:mm",
      substitutions = {},
    },

    completion = {
      blink = true,
      min_chars = 2,
    },

    picker = {
      name = "telescope",
    },

    -- Disable obsidian.nvim's UI rendering — markview handles this
    ui = { enable = false },

    -- Don't auto-insert frontmatter on new notes
    frontmatter = {
      enabled = false,
    },

    -- Wikilink style
    link = {
      style = "wiki",
    },

    attachments = {
      folder = "Obsidian/archive/scs",
    },

  },
}
