local handlers = require('orgmode.lsp.handlers')

return function(dispatchers)
  local closing = false
  local srv = {}

  function srv.request(method, params, callback)
    if method == 'initialize' then
      callback(nil, {
        capabilities = {
          documentSymbolProvider = true,
          workspaceSymbolProvider = true,
          completionProvider = {
            triggerCharacters = { '#', '+', ':', '*', '.', '/' },
          },
          referencesProvider = true
        },
      })
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
