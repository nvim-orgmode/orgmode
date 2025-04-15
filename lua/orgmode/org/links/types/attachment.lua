---@class OrgLinkAttachment:OrgLinkType
---@field private attach OrgAttach
local OrgLinkAttachment = {}
OrgLinkAttachment.__index = OrgLinkAttachment

---@param opts { attach: OrgAttach }
function OrgLinkAttachment:new(opts)
  local this = setmetatable({
    attach = opts.attach,
  }, OrgLinkAttachment)
  return this
end

---@return string
function OrgLinkAttachment:get_name()
  return 'attachment'
end

---@param link string
---@return boolean
function OrgLinkAttachment:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end
  self.attach:open(opts.basename, opts.node)
  return true
end

---@param link string
---@return string[]
function OrgLinkAttachment:autocomplete(link)
  local opts = self:_parse(link)
  if not opts then
    return {}
  end
  local complete = self.attach:make_completion({ node = opts.node })
  return vim.tbl_map(function(name)
    return 'attachment:' .. name
  end, complete(opts.basename))
end

---@private
---@param link string
---@return { node: OrgAttachNode, basename: string } | nil
function OrgLinkAttachment:_parse(link)
  local basename = link:match('^attachment:(.+)$')
  if not basename then
    return nil
  end
  return {
    node = self.attach:get_current_node(),
    basename = basename,
  }
end

return OrgLinkAttachment
