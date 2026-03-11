local handlers = require('orgmode.lsp.handlers')

return function(dispatchers)
  local closing = false
  local srv = {}

  local function send_progress(kind, title, percentage)
    dispatchers.notification('$/progress', {
      token = 'orgmode-progress',
      value = {
        kind = kind,
        title = title,
        percentage = percentage,
      },
    })
  end

  function srv.request(method, params, callback)
    if method == 'initialize' then
      send_progress('begin', 'Initializing orgmode LSP server...', 0)
      callback(nil, {
        capabilities = {
          documentSymbolProvider = true,
          workspaceSymbolProvider = true,
          completionProvider = {
            triggerCharacters = { '#', '+', ':', '*', '.', '/' },
          },
          referencesProvider = true,
        },
      })
      send_progress('end', 'Orgmode LSP server loaded.', 100)
    elseif method == 'shutdown' then
      callback(nil, nil)
    elseif handlers[method] then
      vim.schedule(function()
        callback(nil, handlers[method](params))
      end)
    end
    return true, 1
  end

  function srv.notify(method)
    if method == 'exit' then
      dispatchers.on_exit(0, 15)
    end
  end

  function srv.is_closing()
    return closing
  end

  function srv.terminate()
    closing = true
  end

  return srv
end
