local parsing = require('orgmode.utils.parsing')

--- @class TodoConfig
--- @field words TodoConfigWord[]
local TodoConfig = {}
TodoConfig.__index = TodoConfig

--- @alias TodoConfigRecordBehavior 'time' | 'note' | false

--- @class TodoConfigWord
--- @field name string
--- @field is_active boolean
--- @field hotkey string
--- @field on_enter TodoConfigRecordBehavior
--- @field on_leave TodoConfigRecordBehavior
local TodoConfigWord = {}

--- @param words TodoConfigWord[]
--- @return TodoConfig
function TodoConfig:_new(words)
  --- @type TodoConfig
  local instance = {}
  setmetatable(instance, TodoConfig)

  instance.words = words

  return instance
end

--- @param input string
--- @return TodoConfig?, string
function TodoConfig:parse(input)
  local original = input

  --- @type TodoConfigWord[]
  local active
  active, input = parsing.parse_delimited_sequence(input, function(inner_input)
    return TodoConfigWord:parse(inner_input, true)
  end, '%s+')

  if #active == 0 then
    return nil, original
  end

  local pipe
  pipe, input = parsing.parse_pattern(input, '%s*%|%s*')
  if pipe == nil then
    return nil, original
  end

  --- @type TodoConfigWord[]
  local inactive
  inactive, input = parsing.parse_delimited_sequence(input, function(inner_input)
    return TodoConfigWord:parse(inner_input, false)
  end, '%s+')

  if #inactive == 0 then
    return nil, original
  end

  --- @type TodoConfigWord[]
  local words = {}
  for _, x in ipairs(active) do
    table.insert(words, x)
  end
  for _, x in ipairs(inactive) do
    table.insert(words, x)
  end

  return TodoConfig:_new(words), input
end
end

--- @param name string
--- @param hotkey string
--- @param is_active boolean
--- @param on_enter TodoConfigRecordBehavior
--- @param on_leave TodoConfigRecordBehavior
--- @return TodoConfigWord
function TodoConfigWord:_new(name, is_active, hotkey, on_enter, on_leave)
  --- @type TodoConfigWord
  local instance = {}
  setmetatable(instance, TodoConfigWord)

  instance.name = name
  instance.is_active = is_active
  instance.hotkey = hotkey
  instance.on_enter = on_enter
  instance.on_leave = on_leave

  return instance
end

--- @param input string
--- @param is_active boolean
--- @return TodoConfigWord?, string
function TodoConfigWord:parse(input, is_active)
  local original = input

  --- @type string?, string?, string?, string?
  local name, open, hotkey, enter, slash, leave, close

  name, input = parsing.parse_pattern(input, '%w+')
  if name == nil then
    return nil, original
  end

  open, input = parsing.parse_pattern(input, '%(')
  if open == nil then
    return nil, original
  end

  hotkey, input = parsing.parse_pattern(input, '%w')
  if hotkey == nil then
    return nil, original
  end

  ---@type TodoConfigRecordBehavior
  local on_enter = false
  enter, input = parsing.parse_pattern_choice(input, '%@', '%!')
  if enter ~= nil then
    if enter == '!' then
      on_enter = 'time'
    elseif enter == '@' then
      on_enter = 'note'
    else
      return nil, original
    end
  end

  --- @type TodoConfigRecordBehavior
  local on_leave = false
  slash, input = parsing.parse_pattern(input, '%/')
  if slash ~= nil then
    leave, input = parsing.parse_pattern_choice(input, '%@', '%!')
    if leave == nil then
      return nil, original
    end

    if leave == '!' then
      on_leave = 'time'
    elseif leave == '@' then
      on_leave = 'note'
    else
      return nil, original
    end
  end

  close, input = parsing.parse_pattern(input, '%)')
  if close == nil then
    return nil, original
  end

  local word = TodoConfigWord:_new(name, is_active, hotkey, on_enter, on_leave)
  return word, input
end

return TodoConfig
