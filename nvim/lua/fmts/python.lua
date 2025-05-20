local conform = require("conform")

return function(bufnr)
  local ruff = conform.get_formatter_info("ruff_format", bufnr).available
  if ruff then
    return { "ruff_format" }
  end
  return { "isort", "black" }
end
