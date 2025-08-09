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
  local full_base = string.sub(line, offset)

  -- Create a simplified base that preserves completion context but avoids over-filtering
  local simplified_base = full_base

  -- For file links, keep only the protocol part to preserve context
  if full_base:match('^file:') then
    simplified_base = 'file:'
  elseif full_base:match('^~/') then
    simplified_base = '~/'
  elseif full_base:match('^%./') then
    simplified_base = './'
  elseif full_base:match('^/') then
    simplified_base = '/'
  -- For other contexts, use a minimal base to get all results
  elseif full_base:match('^%*') then
    simplified_base = '*'
  elseif full_base:match('^#%+') then
    simplified_base = '#+'
  elseif full_base:match('^:') then
    simplified_base = ':'
  end

  -- Pass simplified base to orgmode sources to preserve context but get more results
  local results = org.completion:complete({
    line = line,
    base = simplified_base,
    framework = 'blink', -- Still signal framework for any remaining filtering
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
    if #word > 1 and word:sub(1, 2) == '#+' then
      return 0
    end
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

  -- Use full_base for insertText calculation
  local baseOffset = getInsertTextOffset(full_base)
  local insertTextOffset = baseOffset > 0 and math.max(2, baseOffset) or 0

  local items = {}

  for _, item in ipairs(results) do
    table.insert(items, {
      label = item.word,
      filterText = item.word, -- Text to fuzzy match against
      insertText = insertTextOffset > 0 and item.word:sub(insertTextOffset) or item.word,
      labelDetails = item.menu and { description = item.menu } or nil,
    })
  end

  return cb(items)
end

return Source
