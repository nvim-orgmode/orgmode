local function parse_headline(line, current_headline)
  local entry = {
    level = #line:match('^%*+'),
    parent = current_headline,
    line = line,
    headlines = {},
    content = {}
  }
  table.insert(current_headline.headlines, entry)
  return entry
end

local function parse_content(line, current_headline)
  local entry = {
    parent = current_headline,
    line = line
  }

  table.insert(current_headline.content, entry)
  return entry
end

local function parse(lines)
  local result = {
    headlines = {},
    content = {},
    level = 0,
  }
  local current_headline = result
  for _, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s')
    if is_headline then
      local level = #line:match('^%*+')
      if level < current_headline.level then
        while current_headline.level > (level - 1) do
          current_headline = current_headline.parent
        end
      end
      local h = parse_headline(line, current_headline)
      current_headline = h
    else
      parse_content(line, current_headline)
    end
  end
  return result
end

return {
  parse = parse
}
