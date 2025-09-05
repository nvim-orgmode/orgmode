---@class OrgHighlighter
---@field namespace number
---@field markup OrgMarkupHighlighter
---@field private stars OrgStarsHighlighter
---@field private todos OrgTodosHighlighter
---@field private foldtext OrgFoldtextHighlighter
---@field private _ephemeral boolean
---@field private buffers table<number, { language_tree: vim.treesitter.LanguageTree | nil, tree: TSTree }>
---@field private parsing table<number, boolean>
local OrgHighlighter = {}

function OrgHighlighter:new()
  local data = {
    namespace = vim.api.nvim_create_namespace('org_custom_highlighter'),
    buffers = {},
    parsing = {},
    -- Use ephemeral for highlights. Added to config to allow toggling from tests.
    _ephemeral = true,
  }
  setmetatable(data, self)
  self.__index = self
  data:_setup()
  return data
end

---@private
function OrgHighlighter:_setup()
  self.stars = require('orgmode.colors.highlighter.stars'):new({ highlighter = self })
  self.markup = require('orgmode.colors.highlighter.markup'):new({ highlighter = self })
  self.todos = require('orgmode.colors.highlighter.todos'):new()
  self.foldtext = require('orgmode.colors.highlighter.foldtext'):new({ highlighter = self })

  vim.api.nvim_set_decoration_provider(self.namespace, {
    on_win = function(...)
      return self:_on_win(...)
    end,
    on_line = function(...)
      return self:_on_line(...)
    end,
  })
end

---@param bufnr number
---@param win number
---@param range { start_line: number, end_line: number } | false
function OrgHighlighter:_parse_tree(bufnr, win, range)
  self.parsing[win] = self.parsing[win]
    or nil
      == self.buffers[bufnr].language_tree:parse(range, function(_, parsed_trees)
        self.buffers[bufnr].tree = parsed_trees and parsed_trees[1]
        if self.parsing[win] then
          self.parsing[win] = false
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim__redraw({ win = win, valid = false, flush = false })
          end
        end
      end)
end

function OrgHighlighter:_on_win(_, win, bufnr, topline, botline)
  local is_org_buffer = vim.bo[bufnr].filetype == 'org'
  if not is_org_buffer then
    return false
  end
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { language_tree = vim.treesitter.get_parser(bufnr, 'org') }
    self:_parse_tree(bufnr, win, false)
    self.buffers[bufnr].language_tree:register_cbs({
      on_detach = function(buf)
        self:_on_detach(buf)
      end,
    })
  else
    self:_parse_tree(bufnr, win, { topline, botline + 1 })
    if self.parsing[win] then
      for line = topline, botline do
        self:_on_line_impl(bufnr, line, true)
      end
      return false
    end
  end
end

function OrgHighlighter:_on_line(_, _, bufnr, line)
  self:_on_line_impl(bufnr, line)
end

---@param bufnr number
---@param line number
---@param use_cache? boolean
function OrgHighlighter:_on_line_impl(bufnr, line, use_cache)
  if self.buffers[bufnr].tree then
    self.markup:on_line(bufnr, line, self.buffers[bufnr].tree, use_cache)
    self.stars:on_line(bufnr, line)
    self.foldtext:on_line(bufnr, line)
  end
end

function OrgHighlighter:_on_detach(bufnr)
  self.markup:on_detach(bufnr)
  self.foldtext:on_detach(bufnr)
  self.buffers[bufnr] = nil
end

return OrgHighlighter
