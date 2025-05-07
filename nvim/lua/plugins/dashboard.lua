return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    local dashboard = require('dashboard')
    local headers = {
      {
        "",
        "    ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
        "    ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
        "    ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
        "    ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
        "    ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
        "    ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
        "",
      },
      {
        "",
        "    ┌───────────────────────────┐",
        "    │  $ nvim init.lua          │",
        "    │ ┌─────────────────────┐   │",
        "    │ │  require('plugins') │   │",
        "    │ │  require('config')  │   │",
        "    │ │  require('theme')   │   │",
        "    │ └─────────────────────┘   │",
        "    │  [+] Ready to code        │",
        "    └───────────────────────────┘",
        "",
      },
      {
        "",
        "⠀⠀⠀⠀⠀⣀⣠⣤⣤⣤⣤⣄⣀⠀⠀⠀⠀⠀  ",
        "⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀  ",
        "⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⢿⣿⣷⡀⠀  ",
        "⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⣴⢿⣿⣧⠀  ",
        "⣿⣿⣿⣿⣿⡿⠛⣩⠍⠀⠀⠀⠐⠉⢠⣿⣿⡇  ",
        "⣿⡿⠛⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿  ",
        "⢹⣿⣤⠄⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⡏  ",
        "⠀⠻⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⠟⠀  ",
        "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⠟⠁⠀⠀  ",
        "⠀⠀  N E O V I M     ",
        "",
      },
      {
        "",
        "   ⣴⣶⣤⡤⠦⣤⣀⣤⠆     ⣈⣭⣿⣶⣿⣦⣼⣆          ",
        "    ⠉⠻⢿⣿⠿⣿⣿⣶⣦⠤⠄⡠⢾⣿⣿⡿⠋⠉⠉⠻⣿⣿⡛⣦       ",
        "          ⠈⢿⣿⣟⠦ ⣾⣿⣿⣷    ⠻⠿⢿⣿⣧⣄     ",
        "           ⣸⣿⣿⢧ ⢻⠻⣿⣿⣷⣄⣀⠄⠢⣀⡀⠈⠙⠿⠄    ",
        "          ⢠⣿⣿⣿⠈    ⣻⣿⣿⣿⣿⣿⣿⣿⣛⣳⣤⣀⣀   ",
        "   ⢠⣧⣶⣥⡤⢄ ⣸⣿⣿⠘  ⢀⣴⣿⣿⡿⠛⣿⣿⣧⠈⢿⠿⠟⠛⠻⠿⠄  ",
        "  ⣰⣿⣿⠛⠻⣿⣿⡦⢹⣿⣷   ⢊⣿⣿⡏  ⢸⣿⣿⡇ ⢀⣠⣄⣾⠄   ",
        " ⣠⣿⠿⠛ ⢀⣿⣿⣷⠘⢿⣿⣦⡀ ⢸⢿⣿⣿⣄ ⣸⣿⣿⡇⣪⣿⡿⠿⣿⣷⡄  ",
        " ⠙⠃   ⣼⣿⡟  ⠈⠻⣿⣿⣦⣌⡇⠻⣿⣿⣷⣿⣿⣿ ⣿⣿⡇ ⠛⠻⢷⣄ ",
        "      ⢻⣿⣿⣄   ⠈⠻⣿⣿⣿⣷⣿⣿⣿⣿⣿⡟ ⠫⢿⣿⡆     ",
        "       ⠻⣿⣿⣿⣿⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟⢀⣀⣤⣾⡿⠃     ",
        "",
        " N E O V I M ",
        "",
      },
      {
        "",
        "                                     ,",
        "              ,-.       _,---._ __  / \\",
        "             /  )    .-'       `./ /   \\",
        "            (  (   ,'            `/    /|",
        "             \\  `-\"             \\'\\   / |",
        "              `.              ,  \\ \\ /  |",
        "               /`.          ,'-`----Y   |",
        "              (            ;        |   '",
        "              |  ,-.    ,-'         |  /",
        "              |  | (   |        hjw | /",
        "              )  |  \\  `.___________|/",
        "              `--'   `--'",
        "",
        " N E O V I M ",
        "",
      },
      {
        "",
        "             ((((                ",
        "            ((((                 ",
        "             ))))               ",
        "          _ .---.               ",
        "         ( |`---'|              ",
        "          \\|     |             ",
        "          : .___, :             ",
        "           `-----'              ",
        " N E O V I M ",
        "",
      },
    }

    math.randomseed(os.time())
    local random_header = headers[math.random(#headers)]
    dashboard.setup {
      theme = 'hyper',
      config = {
        header = random_header,
        shortcut = {
          { desc = ' Find File',      group = 'DashboardFiles', key = 'f', action = 'Telescope find_files' },
          { desc = ' Recent Files',   group = 'DashboardFiles', key = 'r', action = 'Telescope oldfiles' },
          { desc = ' Find Word',      group = 'DashboardFiles', key = 'w', action = 'Telescope live_grep' },
          { desc = ' New File',       group = 'DashboardFiles', key = 'n', action = 'enew' },
          { desc = ' Settings',       group = 'DashboardFiles', key = 's', action = 'e $MYVIMRC' },
          { desc = ' Update Plugins', group = 'DashboardFiles', key = 'u', action = 'Lazy update' },
        },
        packages = {
          enable = true -- Shows plugin count
        },
        project = {
          enable = true,
          limit = 8,
          icon = '',
          label = 'Recent Projects',
          action = 'Telescope find_files cwd='
        },
        mru = {
          enable = true,
          limit = 10,
          icon = '',
          label = 'Recent Files',
        },
        footer = {
          "",
          os.date("%H:%M") .. " " .. ({ "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘" })[tonumber(os.date("%d")) % 8 + 1] .. " " .. os.date("%d %b, %a"),
          "", "󰍛 " .. io.popen("whoami"):read("*l") .. "@" .. io.popen("hostname"):read("*l")
        .. " 󰌪 " .. io.popen('uptime -p'):read("*l"),
        }
      },
      hide = {
        statusline = true,      -- Set to true to hide statusline in dashboard
        tabline = true,         -- Set to true to hide tabline in dashboard
        winbar = true           -- Set to true to hide winbar in dashboard
      },
      disable_move = false,     -- Set to true to disable cursor movement in dashboard
      shortcut_type = 'letter', -- 'letter' for a-z shortcuts, 'number' for numeric shortcuts
      change_to_vcs_root = true -- Change to project root when opening files from MRU
    }
  end,
  dependencies = {
    { 'nvim-tree/nvim-web-devicons' },
    { 'nvim-telescope/telescope.nvim' }
  }
}
