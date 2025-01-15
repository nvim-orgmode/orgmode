-- Source code completely taken from https://github.com/kdheepak/panvimdoc
-- Only modified to include both lvl 3 and lvl 4 headers in the docmapping
PANDOC_VERSION:must_be_at_least("3.0")

local pipe = pandoc.pipe
local stringify = (require("pandoc.utils")).stringify
local text = pandoc.text

function P(s)
  require("scripts.logging").temp(s)
end

-- custom writer for pandoc

local unpack = unpack or table.unpack
local format = string.format
local stringify = pandoc.utils.stringify
local layout = pandoc.layout
local to_roman = pandoc.utils.to_roman_numeral

function string.starts_with(str, starts)
  return str:sub(1, #starts) == starts
end

function string.ends_with(str, ends)
  return ends == "" or str:sub(-#ends) == ends
end

-- Character escaping
local function escape(s, in_attribute)
  return s
end

local function indent(s, fl, ol)
  local ret = {}
  local i = 1
  for l in s:gmatch("[^\r\n]+") do
    if i == 1 then
      ret[i] = fl .. l
    else
      ret[i] = ol .. l
    end
    i = i + 1
  end
  return table.concat(ret, "\n")
end

Writer = pandoc.scaffolding.Writer

local function inlines(ils)
  local buff = {}
  for i = 1, #ils do
    local el = ils[i]
    buff[#buff + 1] = Writer[pandoc.utils.type(el)][el.tag](el)
  end
  return table.concat(buff)
end

local function blocks(bs, sep)
  local dbuff = {}
  for i = 1, #bs do
    local el = bs[i]
    dbuff[#dbuff + 1] = Writer[pandoc.utils.type(el)][el.tag](el)
  end
  return table.concat(dbuff, sep)
end

local PROJECT = ""
local TREESITTER = false
local TOC = false
local VIMVERSION = "0.9.0"
local DESCRIPTION = ""
local DEDUP_SUBHEADINGS = false
local IGNORE_RAWBLOCKS = true
local DOC_MAPPING = true
local DOC_MAPPING_PROJECT = true
local DATE = nil
local TITLE_DATE_PATTERN = "%Y %B %d"

local CURRENT_HEADER = nil
local SOFTBREAK_TO_HARDBREAK = "space"

local HEADER_COUNT = 1
local toc = {}
local links = {}

local function osExecute(cmd)
  local fileHandle = assert(io.popen(cmd, "r"))
  local commandOutput = assert(fileHandle:read("*a"))
  local returnTable = { fileHandle:close() }
  return commandOutput, returnTable[3] -- rc[3] contains returnCode
end

local function renderTitle()
  local t = {}
  local function add(s)
    table.insert(t, s)
  end
  local vim_doc_title = PROJECT .. ".txt"
  local vim_doc_title_tag = "*" .. vim_doc_title .. "*"
  local project_description = DESCRIPTION or ""
  if not project_description or #project_description == 0 then
    local vim_version = VIMVERSION
    if vim_version == nil then
      vim_version = osExecute("nvim --version"):gmatch("([^\n]*)\n?")()
      if string.find(vim_version, "-dev") then
        vim_version = string.gsub(vim_version, "(.*)-dev.*", "%1")
      end
      if vim_version == "" then
        vim_version = osExecute("vim --version"):gmatch("([^\n]*)\n?")()
        vim_version = string.gsub(vim_version, "(.*) %(.*%)", "%1")
      end
      if vim_version == "" then
        vim_version = "vim"
      end
    elseif vim_version == "vim" then
      vim_version = osExecute("vim --version"):gmatch("([^\n]*)\n?")()
    end

    local date = DATE
    if date == nil then
      date = os.date(TITLE_DATE_PATTERN)
    end
    local m = "For " .. vim_version
    local r = "Last change: " .. date
    local n = math.max(0, 78 - #vim_doc_title_tag - #m - #r)
    local s = string.rep(" ", math.floor(n / 2))
    project_description = s .. m .. s .. r
  end
  local padding_len = math.max(0, 78 - #vim_doc_title_tag - #project_description)
  add(vim_doc_title_tag .. string.rep(" ", padding_len) .. project_description)
  add("")
  return table.concat(t, "\n")
end

local function renderToc()
  if TOC then
    local t = {}
    local function add(s)
      table.insert(t, s)
    end
    add(string.rep("=", 78))
    local l = "Table of Contents"
    local tag = "*" .. PROJECT .. "-" .. string.gsub(string.lower(l), "%s", "-") .. "*"
    add(l .. string.rep(" ", 78 - #l - #tag) .. tag)
    add("")
    for _, elem in pairs(toc) do
      local level, item, link = elem[1], elem[2], elem[3]
      if level == 1 then
        local padding = string.rep(" ", 78 - #item - #link)
        add(item .. padding .. link)
      elseif level == 2 then
        local padding = string.rep(" ", 74 - #item - #link)
        add("  - " .. item .. padding .. link)
      end
    end
    add("")
    return table.concat(t, "\n")
  else
    return ""
  end
end

local function renderNotes()
  local t = {}
  local function add(s)
    table.insert(t, s)
  end
  if #links > 0 then
    local left = HEADER_COUNT .. ". Links"
    local right = "links"
    local right_link = string.format("|%s-%s|", PROJECT, right)
    right = string.format("*%s-%s*", PROJECT, right)
    local padding = string.rep(" ", 78 - #left - #right)
    table.insert(toc, { 1, left, right_link })
    add(string.rep("=", 78) .. "\n" .. string.format("%s%s%s", left, padding, right))
    add("")
    for i, v in ipairs(links) do
      add(i .. ". *" .. v.caption .. "*" .. ": " .. v.src)
    end
  end
  return table.concat(t, "\n") .. "\n"
end

local function renderFooter()
  return [[Generated by panvimdoc <https://github.com/kdheepak/panvimdoc>

vim:tw=78:ts=8:noet:ft=help:norl:]]
end

Writer.Pandoc = function(doc, opts)
  PROJECT = doc.meta.project
  TREESITTER = doc.meta.treesitter
  TOC = doc.meta.toc
  VIMVERSION = doc.meta.vimversion
  DESCRIPTION = doc.meta.description
  DEDUP_SUBHEADINGS = doc.meta.dedupsubheadings
  IGNORE_RAWBLOCKS = doc.meta.ignorerawblocks
  DOC_MAPPING = doc.meta.docmapping
  DOC_MAPPING_PROJECT = doc.meta.docmappingproject
  HEADER_COUNT = HEADER_COUNT + doc.meta.incrementheadinglevelby
  DATE = doc.meta.date
  TITLE_DATE_PATTERN = doc.meta.titledatepattern
  local d = blocks(doc.blocks)
  local notes = renderNotes()
  local toc = renderToc()
  local title = renderTitle()
  local footer = renderFooter()
  return { title, layout.blankline, toc, d, notes, layout.blankline, footer }
end

Writer.Block.Header = function(el)
  local lev = el.level
  local s = stringify(el)
  local attr = el.attr
  local left, right, right_link, padding
  if lev == 1 then
    left = string.format("%d. %s", HEADER_COUNT, s)
    right = string.lower(string.gsub(s, "%s", "-"))
    CURRENT_HEADER = right
    right_link = string.format("|%s-%s|", PROJECT, right)
    right = string.format("*%s-%s*", PROJECT, right)
    padding = string.rep(" ", 78 - #left - #right)
    table.insert(toc, { 1, left, right_link })
    s = string.format("%s%s%s", left, padding, right)
    HEADER_COUNT = HEADER_COUNT + 1
    s = string.rep("=", 78) .. "\n" .. s
    return "\n" .. s .. "\n\n"
  end
  if lev == 2 then
    left = string.upper(s)
    right = string.lower(string.gsub(s, "%s", "-"))
    if DEDUP_SUBHEADINGS and CURRENT_HEADER then
      right_link = string.format("|%s-%s-%s|", PROJECT, CURRENT_HEADER, right)
      right = string.format("*%s-%s-%s*", PROJECT, CURRENT_HEADER, right)
    else
      right_link = string.format("|%s-%s|", PROJECT, right)
      right = string.format("*%s-%s*", PROJECT, right)
    end
    padding = string.rep(" ", 78 - #left - #right)
    table.insert(toc, { 2, s, right_link })
    s = string.format("%s%s%s", left, padding, right)
    return "\n" .. s .. "\n\n"
  end
  -- if lev == 3 then
  --   left = string.upper(s)
  --   return "\n" .. left .. " ~" .. "\n\n"
  -- end
  -- Add link to both level 3 and level 4
  if lev == 3 or lev == 4 then
    if DOC_MAPPING then
      left = s
      if attr.attributes.doc then
        right = "*" .. attr.attributes.doc .. "*"
      elseif DOC_MAPPING_PROJECT then
          -- stylua: ignore
          right = string.format(
            "*%s-%s*",
            PROJECT,
            s:gsub("{.+}", "")
            :gsub("%[.+%]", "")
            :gsub("^%s*(.-)%s*$", "%1")
            :gsub("^%s*(.-)%s*$", "%1")
            :gsub("%s", "-")
          )
      else
          -- stylua: ignore
          right = string.format(
            "*%s*",
            s:gsub("{.+}", "")
            :gsub("%[.+%]", "")
            :gsub("^%s*(.-)%s*$", "%1")
            :gsub("^%s*(.-)%s*$", "%1")
            :gsub("%s", "-")
          )
      end
      padding = string.rep(" ", 78 - #left - #right)
      local r = string.format("%s%s%s", left, padding, right)
      return "\n" .. r .. "\n\n"
    else
      left = string.upper(s)
      return "\n" .. left .. "\n\n"
    end
  end
  if lev >= 5 then
    left = string.upper(s)
    return "\n" .. left .. "\n\n"
  end
end

Writer.Block.Para = function(el)
  local s = inlines(el.content)
  local t = {}
  local current_line = ""
  for word in string.gmatch(s, "([^%s]+)") do
    if string.match(word, "[.]") and #word == 1 then
      current_line = current_line .. word
    elseif (#current_line + #word) > 78 then
      table.insert(t, current_line)
      current_line = word
    elseif #current_line == 0 then
      current_line = word
    else
      current_line = current_line .. " " .. word
    end
  end
  table.insert(t, current_line)
  return table.concat(t, "\n") .. "\n\n"
end

Writer.Block.OrderedList = function(items)
  local buffer = {}
  local i = 1
  items.content:map(function(item)
    table.insert(buffer, ("%s. %s"):format(i, blocks(item)))
    i = i + 1
  end)
  return table.concat(buffer, "\n") .. "\n\n"
end

Writer.Block.BulletList = function(items)
  local buffer = {}
  items.content:map(function(item)
    table.insert(buffer, indent(blocks(item, "\n"), "- ", "    "))
  end)
  return table.concat(buffer, "\n") .. "\n\n"
end

Writer.Block.DefinitionList = function(el)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  el.content:map(function(item)
    local k = inlines(item[1])
    local bs = item[2][1]
    local t = {}
    for i = 1, #bs do
      local e = bs[i]
      if e.tag == "Para" then
        local tt = {}
        e.content:map(function(i)
          if i.tag == "SoftBreak" then
            table.insert(tt, "\n")
          else
            table.insert(tt, Writer[pandoc.utils.type(i)][i.tag](i))
          end
        end)
        table.insert(t, table.concat(tt))
      else
        table.insert(t, Writer[pandoc.utils.type(e)][e.tag](e))
      end
    end
    local str = table.concat(t, "\n")
    local i = 1

    local right = ""
    if DOC_MAPPING_PROJECT then
      -- stylua: ignore
      right = string.format(
        "*%s-%s*",
        PROJECT,
        k:gsub("{.+}", "")
        :gsub("%[.+%]", "")
        :gsub("^%s*(.-)%s*$", "%1")
        :gsub("^%s*(.-)%s*$", "%1")
        :gsub("%s", "-")
      )
    else
      -- stylua: ignore
      right = string.format(
        "*%s*",
        k:gsub("{.+}", "")
        :gsub("%[.+%]", "")
        :gsub("^%s*(.-)%s*$", "%1")
        :gsub("^%s*(.-)%s*$", "%1")
        :gsub("%s", "-")
      )
    end
    add(string.rep(" ", 78 - #right - 2) .. right)
    add("\n")
    for s in str:gmatch("[^\r\n]+") do
      if i == 1 then
        add(k .. string.rep(" ", 78 - 40 + 1 - #k) .. s)
      else
        add(string.rep(" ", 78 - 40 + 1) .. s)
      end
      i = i + 1
    end
    add("\n")
  end)
  return "\n" .. table.concat(buffer, "\n") .. "\n\n"
end

Writer.Block.CodeBlock = function(el)
  local attr = el.attr
  local s = el.text
  if #attr.classes > 0 and attr.classes[1] == "vimdoc" then
    return s .. "\n\n"
  else
    local lang = ""
    if TREESITTER and #attr.classes > 0 then
      lang = attr.classes[1]
    end
    local t = {}
    for line in s:gmatch("([^\n]*)\n?") do
      table.insert(t, "    " .. escape(line))
    end
    return ">" .. lang .. "\n" .. table.concat(t, "\n") .. "\n<\n\n"
  end
end

Writer.Inline.Str = function(el)
  local s = stringify(el)
  if string.starts_with(s, "(http") and string.ends_with(s, ")") then
    return " <" .. string.sub(s, 2, #s - 2) .. ">"
  else
    return escape(s)
  end
end

Writer.Inline.Space = function()
  return " "
end

Writer.Inline.SoftBreak = function()
  if SOFTBREAK_TO_HARDBREAK == "newline" then
    return "\n"
  elseif SOFTBREAK_TO_HARDBREAK == "space" then
    return "\n"
  else
    return ""
  end
end

Writer.Inline.LineBreak = function()
  return "\n"
end

Writer.Inline.Emph = function(s)
  return "_" .. stringify(s) .. "_"
end

Writer.Inline.Strong = function(s)
  return "**" .. stringify(s) .. "**"
end

Writer.Inline.Subscript = function(s)
  return "_" .. stringify(s)
end

Writer.Inline.Superscript = function(s)
  return "^" .. stringify(s)
end

Writer.Inline.SmallCaps = function(s)
  return stringify(s)
end

Writer.Inline.Strikeout = function(s)
  return "~" .. stringify(s) .. "~"
end

Writer.Inline.Link = function(el)
  local s = inlines(el.content)
  local tgt = el.target
  local tit = el.title
  local attr = el.attr
  if string.starts_with(tgt, "https://neovim.io/doc/") then
    return "|" .. s .. "|"
  elseif string.starts_with(tgt, "#") then
    return "|" .. PROJECT .. "-" .. s:lower():gsub("%s", "-") .. "|"
  elseif string.starts_with(s, "http") then
    return "<" .. s .. ">"
  else
    return s .. " <" .. tgt .. ">"
  end
end

Writer.Inline.Image = function(el)
  links[#links + 1] = { caption = inlines(el.caption), src = el.src }
end

Writer.Inline.Code = function(el)
  local content = stringify(el)
  local vim_help = string.match(content, "^:h %s*([^%s]+)")
  if vim_help then
    return string.format("|%s|", escape(vim_help))
  else
    return "`" .. escape(content) .. "`"
  end
end

Writer.Inline.Math = function(s)
  return "`" .. escape(stringify(s)) .. "`"
end

Writer.Inline.Quoted = function(el)
  if el.quotetype == "DoubleQuote" then
    return "\"" .. inlines(el.content) .. "\""
  else
    return "'" .. inlines(el.content) .. "'"
  end
end

Writer.Inline.Note = function(el)
  return stringify(el)
end

Writer.Inline.Null = function(s)
  return ""
end

Writer.Inline.Span = function(el)
  return inlines(el.content)
end

Writer.Inline.RawInline = function(el)
  if IGNORE_RAWBLOCKS then
    return ""
  end
  local str = el.text
  if format == "html" then
    if str == "<b>" then
      return ""
    elseif str == "</b>" then
      return " ~"
    elseif str == "<i>" or str == "</i>" then
      return "_"
    elseif str == "<kbd>" or str == "</kbd>" then
      return ""
    else
      return str
    end
  else
    return ""
  end
end

Writer.Inline.Citation = function(el)
  return el
end

Writer.Inline.Cite = function(el)
  links[#links + 1] = { caption = inlines(el.content), src = "" }
  return inlines(el.content)
end

Writer.Block.Plain = function(el)
  return inlines(el.content)
end

Writer.Block.RawBlock = function(el)
  local fmt = el.format
  local str = el.text
  if fmt == "html" then
    if string.starts_with(str, "<!--") then
      return ""
    elseif str == "<p>" or str == "</p>" then
      return ""
    elseif str == "<details>" or str == "</details>" then
      return ""
    elseif str == "<summary>" then
      return ""
    elseif str == "</summary>" then
      return " ~\n\n"
    elseif IGNORE_RAWBLOCKS then
      return ""
    else
      return str
    end
  else
    return ""
  end
end

Writer.Block.Table = function(el)
  return pandoc.write(pandoc.Pandoc({ el }), "plain")
end

Writer.Block.Div = function(el)
  -- TODO: Add more special features here
  if IGNORE_RAWBLOCKS then
    return "\n"
  else
    return blocks(el.content)
  end
end

Writer.Block.Figure = function(el)
  return blocks(el.content)
end

Writer.Block.BlockQuote = function(el)
  local lines = {}
  for line in blocks(el.content):gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return "\n  " .. table.concat(lines, "\n  ") .. "\n"
end

Writer.Block.HorizontalRule = function()
  return string.rep("-", 78) .. "\n"
end

Writer.Block.LineBlock = function(el)
  local buffer = {}
  el.content:map(function(item)
    table.insert(buffer, table.concat({ "| ", inlines(item) }))
  end)
  return "\n" .. table.concat(buffer, "\n") .. "\n"
end
