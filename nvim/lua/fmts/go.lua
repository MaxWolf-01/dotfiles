local conform = require("conform")

--- @param bufnr integer
--- @return table<string>
return function(bufnr)
  local gofumpt = conform.get_formatter_info("gofumpt", bufnr).available
  if gofumpt then
    return { "goimports", "gofumpt" }
  end
  return { "goimports", "gofmt" }
end
