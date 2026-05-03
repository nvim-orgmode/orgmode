local Range = require('orgmode.files.elements.range')

---@class OrgMarkupPreparedHighlight
---@field start_line number
---@field start_col number
---@field end_col number
---@field hl_group string
---@field spell? boolean
---@field priority number
---@field conceal? boolean
---@field ephemeral boolean
---@field url? string

---@class OrgAgendaLineTokenOpts
---@field content string
---@field range? OrgRange
---@field virt_text_pos? string
---@field hl_group? string
---@field trim_for_hl? boolean
---@field add_markup_to_headline? OrgHeadline

---@class OrgAgendaLineToken: OrgAgendaLineTokenOpts
local OrgAgendaLineToken = {}
OrgAgendaLineToken.__index = OrgAgendaLineToken

---@param opts OrgAgendaLineTokenOpts
---@return OrgAgendaLineToken
function OrgAgendaLineToken:new(opts)
  local data = {
    content = opts.content,
    range = opts.range,
    hl_group = opts.hl_group,
    virt_text_pos = opts.virt_text_pos,
    trim_for_hl = opts.trim_for_hl,
    add_markup_to_headline = opts.add_markup_to_headline,
  }
  return setmetatable(data, OrgAgendaLineToken)
end

---@private
---@param headline OrgHeadline
---@param node TSNode
---@param result OrgMarkupPreparedHighlight[]
function OrgAgendaLineToken:_prepare_link_highlight(headline, node, result)
  local url = node:field('url')[1]
  local desc = node:field('desc')[1]
  local url_target = nil

  if desc then
    local sld, scd, _, ecd = desc:range()
    table.insert(result, {
      start_line = sld,
      start_col = scd,
      end_col = ecd,
      hl_group = '@org.hyperlink.desc',
    })
    table.insert(result, {
      start_line = sld,
      start_col = scd - 2,
      end_col = scd,
      conceal = '',
    })
  end

  if url then
    local slu, scu, _, ecu = url:range()
    table.insert(result, {
      start_line = slu,
      start_col = scu,
      end_col = ecu,
      hl_group = '@org.hyperlink.url',
      spell = false,
      conceal = desc and '' or nil,
    })
    url_target = headline.file:get_node_text(url)
  end
  local sl, sc, _, ec = node:range()
  table.insert(result, {
    start_line = sl,
    start_col = sc,
    end_col = ec,
    hl_group = '@org.hyperlink',
    url = url_target,
  })
  table.insert(result, {
    start_line = sl,
    start_col = sc,
    end_col = sc + 2,
    conceal = '',
  })
  table.insert(result, {
    start_line = sl,
    start_col = ec - 2,
    end_col = ec,
    conceal = '',
  })
end

---@private
---@param node TSNode
---@param result OrgMarkupPreparedHighlight[]
function OrgAgendaLineToken:_prepare_date_highlight(node, result)
  local sl, sc, _, ec = node:range()
  table.insert(result, {
    start_line = sl,
    start_col = sc,
    end_col = ec,
    hl_group = node:child(0):type() == '<' and '@org.timestamp.active' or '@org.timestamp.inactive',
  })
end

---@private
---@param headline OrgHeadline
---@return OrgMarkupPreparedHighlight[]
function OrgAgendaLineToken:_prepare_ts_highlights(headline)
  local headline_item_node = headline:node():field('item')[1]
  if not headline_item_node then
    return {}
  end
  local result = {}
  for node in headline_item_node:iter_children() do
    if node:type() == 'link' or node:type() == 'link_desc' then
      self:_prepare_link_highlight(headline, node, result)
    end
    if node:type() == 'timestamp' then
      self:_prepare_date_highlight(node, result)
    end
  end
  return result
end

function OrgAgendaLineToken:get_highlights()
  local highlights = {}
  if self.hl_group and not self.virt_text_pos then
    local range = self.range
    if self.trim_for_hl then
      range = self.range:clone()
      local start_offset = self.content:match('^%s*')
      local end_offset = self.content:match('%s*$')
      range.start_col = range.start_col + (start_offset and #start_offset or 0)
      range.end_col = range.end_col - (end_offset and #end_offset or 0)
    end

    table.insert(highlights, {
      hlgroup = self.hl_group,
      range = range,
    })
  end

  if self.add_markup_to_headline then
    local markup_highlights = self:_prepare_ts_highlights(self.add_markup_to_headline)
    local _, offset = self.add_markup_to_headline:get_title()

    for _, hl in ipairs(markup_highlights) do
      table.insert(highlights, {
        hlgroup = hl.hl_group,
        extmark = true,
        range = Range:new({
          start_line = self.range.start_line,
          end_line = self.range.end_line,
          start_col = self.range.start_col + hl.start_col - offset,
          end_col = self.range.start_col + hl.end_col - offset,
        }),
        priority = hl.priority,
        conceal = hl.conceal,
        spell = hl.spell,
        url = hl.url,
      })
    end
  end
  return highlights
end

return OrgAgendaLineToken
