local utils = require('orgmode.utils')
local Link = require('orgmode.org.hyperlinks.link')

return function(protocol, components)
  for _, component in pairs(components) do
    if not (type(component) == 'string') then
      return nil
    end
  end

  ---@class OrgLinkAlias:OrgLink
  local Alias = Link:new(protocol)
  Alias.components = components

  ---@param input string
  function Alias.parse(input)
    local processed_components = {}
    for _, component in pairs(Alias.components) do
      ---@cast component string
      if component == '%s' then
        table.insert(processed_components, input)
        goto continue
      end
      if component == '%h' then
        table.insert(processed_components, vim.uri_encode(input))
        goto continue
      end
      if component:find('^%%%b()$') then
        local func = component:sub(3, -2)
        table.insert(processed_components, vim.fn.luaeval(('%s(_A)'):format(func), input))
        goto continue
      end
      table.insert(processed_components, component)
      ::continue::
    end

    return Link.parse(table.concat(processed_components))
  end

  return Alias
end
