local has_compe, compe = pcall(require, 'compe')
if not has_compe then
  return
end

local OrgmodeOmniCompletion = require('orgmode.org.autocompletion.omni')

local CompeSource = {}

function CompeSource.new()
  return setmetatable({}, { __index = CompeSource })
end

function CompeSource.get_metadata()
  return {
    priority = 999,
    sort = false,
    dup = 0,
    filetypes = { 'org' },
    menu = '[Org]',
  }
end

function CompeSource.determine(_, context)
  local offset = OrgmodeOmniCompletion(1, '') + 1
  if offset > 0 then
    return {
      keyword_pattern_offset = offset,
      trigger_character_offset = vim.tbl_contains({ '#', '+', ':', '*' }, context.before_char) and context.col or 0,
    }
  end
end

function CompeSource.complete(_, context)
  local items = OrgmodeOmniCompletion(0, context.input)
  context.callback({
    items = items,
    incomplete = true,
  })
end

compe.register_source('orgmode', CompeSource)
