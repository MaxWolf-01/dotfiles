return {
  "L3MON4D3/LuaSnip",

  config = function()
    local ls = require("luasnip")

    ls.setup({
      enable_autosnippets = true,
    })

    require("luasnip.loaders.from_lua").load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
  end,
}
