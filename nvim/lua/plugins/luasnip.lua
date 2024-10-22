return {
  "L3MON4D3/LuaSnip",

  config = function()
    require("luasnip.loaders.from_lua").load()
    require("luasnip.loaders.from_lua").lazy_load {
      paths = vim.g.lua_snippets_path or "",
    }
  end,
}
