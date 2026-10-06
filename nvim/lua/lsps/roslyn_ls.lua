-- Merged over nvim-lspconfig's lsp/roslyn_ls.lua.

-- Roslyn reports a project it cannot load only as a window/logMessage, which
-- only :LspLog shows; a half-loaded solution then finds no references across
-- projects and flags needed usings as unnecessary.
local warned = {}

return {
  handlers = {
    ["window/logMessage"] = function(err, result, ctx)
      if result and result.type == vim.lsp.protocol.MessageType.Error
          and result.message:find("Error while loading", 1, true)
          and not warned[ctx.client_id] then
        warned[ctx.client_id] = true
        local cause = result.message:match("Exception thrown: ([^\n]+)") or result.message:match("^[^\n]+")
        vim.notify("Roslyn could not load a project; references and diagnostics are incomplete.\n"
          .. cause .. "\nSee :LspLog", vim.log.levels.ERROR, { title = "roslyn_ls" })
      end
      return vim.lsp.handlers["window/logMessage"](err, result, ctx)
    end,
  },
  settings = {
    -- lspconfig analyses the whole solution in the background; open files only
    -- keeps a large solution from loading the CPU all session
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "openFiles",
      dotnet_compiler_diagnostics_scope = "openFiles",
    },
  },
}
