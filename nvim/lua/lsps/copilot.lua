local function sign_in(bufnr, client)
  client:request('signIn', vim.empty_dict(), function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end
    if result.command then
      vim.fn.setreg('+', result.userCode)
      vim.fn.setreg('*', result.userCode)
      local ok = vim.fn.confirm(
        'Copied one-time code to clipboard.\nOpen browser to sign in?',
        '&Yes\n&No'
      )
      if ok == 1 then
        client:exec_cmd(result.command, { bufnr = bufnr }, function(cmd_err, cmd_result)
          if cmd_err then
            vim.notify(cmd_err.message, vim.log.levels.ERROR)
            return
          end
          if cmd_result.status == 'OK' then
            vim.notify('Signed in as ' .. cmd_result.user)
          end
        end)
      end
    elseif result.status == 'PromptUserDeviceFlow' then
      vim.notify('Enter code ' .. result.userCode .. ' at ' .. result.verificationUri)
    elseif result.status == 'AlreadySignedIn' then
      vim.notify('Already signed in as ' .. result.user)
    end
  end)
end

local function sign_out(_, client)
  client:request('signOut', vim.empty_dict(), function(err, result)
    if err then
      vim.notify(err.message, vim.log.levels.ERROR)
      return
    end
    if result.status == 'NotSignedIn' then
      vim.notify('Not signed in.')
    end
  end)
end

--- Truncate insert_text via a transform function, skip the server-side accept command.
local function partial_accept(transform)
  return function(item)
    local text = type(item.insert_text) == 'string' and item.insert_text
      or tostring(item.insert_text.value)
    local partial = transform(text)
    if not partial or partial == '' then return item end
    item.insert_text = partial
    item.command = nil
    return item
  end
end

local accept_word = partial_accept(function(text)
  local word = vim.fn.matchstr(text, [[\k\+\s\?]])
  return word ~= '' and word or text:sub(1, 1)
end)

local accept_line = partial_accept(function(text)
  return text:match('^[^\n]*')
end)

return {
  cmd = { 'copilot-language-server', '--stdio' },
  root_markers = { '.git' },
  init_options = {
    editorInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
    editorPluginInfo = {
      name = 'Neovim',
      version = tostring(vim.version()),
    },
  },
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'CopilotSignIn', function()
      sign_in(bufnr, client)
    end, { desc = 'Sign in to GitHub Copilot' })
    vim.api.nvim_buf_create_user_command(bufnr, 'CopilotSignOut', function()
      sign_out(bufnr, client)
    end, { desc = 'Sign out of GitHub Copilot' })

    if not client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
      return
    end

    vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
    local ic = vim.lsp.inline_completion
    local map = vim.keymap.set

    map('i', '<A-S-s>', function() ic.get() end,
      { buffer = bufnr, desc = 'Copilot: accept suggestion' })

    map('i', '<A-S-w>', function() ic.get({ on_accept = accept_word }) end,
      { buffer = bufnr, desc = 'Copilot: accept word' })

    map('i', '<A-S-q>', function() ic.get({ on_accept = accept_line }) end,
      { buffer = bufnr, desc = 'Copilot: accept line' })

    map('i', '<A-S-d>', function() ic.select() end,
      { buffer = bufnr, desc = 'Copilot: next suggestion' })

    map('i', '<A-S-a>', function() ic.select({ count = -1 }) end,
      { buffer = bufnr, desc = 'Copilot: previous suggestion' })

    map('n', '<leader>cc', function()
      local enabled = ic.is_enabled({ bufnr = bufnr })
      ic.enable(not enabled, { bufnr = bufnr })
      vim.notify('Copilot: ' .. (not enabled and 'ON' or 'OFF'))
    end, { buffer = bufnr, desc = 'Toggle Copilot' })
  end,
}
