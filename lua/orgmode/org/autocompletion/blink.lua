local org = require('orgmode')

local Source = {}

Source.new = function()
  return setmetatable({}, { __index = Source })
end

function Source:enabled()
  return vim.bo.filetype == 'org'
end

function Source:get_trigger_characters(_)
  return { '#', '+', ':', '*', '.', '/' }
end

function Source:get_completions(ctx, callback)
  local line = ctx.line:sub(1, ctx.cursor[2])
  local offset = org.completion:get_start({ line = line }) + 1
  local base = string.sub(line, offset)
  local results = org.completion:complete({
    line = line,
    base = base,
  })

  local cb = function(items)
    callback({
      context = ctx,
      is_incomplete_forward = true,
      is_incomplete_backward = true,
      items = items,
    })
    return function() end
  end

  if not results or #results == 0 then
    return cb({})
  end

  -- Does not contain dot to avoid stopping on file paths
  local triggers = { '#', '+', ':', '*', '/' }

  local getInsertTextOffset = function(word)
    local word_length = #word + 1
    while word_length > 0 do
      local char = word:sub(word_length - 1, word_length - 1)
      if vim.tbl_contains(triggers, char) or char:match('%s') then
        return word_length
      end
      word_length = word_length - 1
    end
    return 0
  end

  local baseOffset = getInsertTextOffset(base)
  local insertTextOffset = baseOffset > 0 and math.max(2, baseOffset) or 0

  local items = {}

  for _, item in ipairs(results) do
    table.insert(items, {
      label = item.word,
      insertText = insertTextOffset > 0 and item.word:sub(insertTextOffset) or item.word,
      labelDetails = item.menu and { description = item.menu } or nil,
    })
  end

  return cb(items)
end

return Source
