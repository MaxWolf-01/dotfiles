local conform = require("conform")

--- @param bufnr integer
--- @return table<string>
return function(bufnr)
  local biome = conform.get_formatter_info("biome", bufnr).available
  if biome then
    return { "biome" }
  end
  return { "prettier", "eslint" }
end
