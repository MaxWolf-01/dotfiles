return {
  'saghen/blink.cmp',
  dependencies = { 'rafamadriz/friendly-snippets' },
  version = 'v0.*',
  
  opts = {
    keymap = { 
      preset = 'enter',  -- Enter to accept
      ['<Tab>'] = { 'select_next', 'fallback' },  -- Add Tab navigation
      ['<S-Tab>'] = { 'select_prev', 'fallback' },  -- Add Shift-Tab navigation
    },
    
    completion = {
      menu = {
        auto_show = true,  -- Show menu automatically as you type
      },
      list = {
        selection = {
          preselect = true,  -- Need this TRUE for super-tab to work properly
          auto_insert = false,  -- Keep false so text doesn't insert until Tab
        }
      },
      documentation = {
        auto_show = true,  -- Show docs when selecting items
        auto_show_delay_ms = 200,
      },
      ghost_text = { 
        enabled = false -- Show inline preview of selected item
      },
    },
    
    -- Experimental signature help (shows function parameters)
    signature = { 
      enabled = true,
      window = {
        show_documentation = false,  -- Only show signature, not full docs
      }
    },
    
    -- Sources configuration
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
      -- Use LuaSnip for snippets since you already have it
      providers = {
        snippets = {
          opts = {
            friendly_snippets = true,
            search_paths = { vim.fn.stdpath('config') .. '/snippets' },
          }
        },
      }
    },
    
    -- Cmdline completion (like : commands and / search)
    cmdline = {
      enabled = true,
      completion = {
        menu = {
          auto_show = true,  -- Show menu automatically, just like regular completion
        },
        ghost_text = {
          enabled = true,  -- Preview the completion inline
        },
      },
    },
    
    -- Appearance
    appearance = {
      nerd_font_variant = 'mono'
    },
  },
  
  -- This ensures the sources.default list can be extended elsewhere
  opts_extend = { "sources.default" }
}
