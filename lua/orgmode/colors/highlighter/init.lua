---@class OrgHighlighter
---@field namespace number
---@field private stars OrgStarsHighlighter
---@field private markup OrgMarkupHighlighter
---@field private todos OrgTodosHighlighter
---@field private foldtext OrgFoldtextHighlighter
---@field private _ephemeral boolean
---@field private buffers table<number, { language_tree: LanguageTree, tree: TSTree }>
local OrgHighlighter = {}
local config = require('orgmode.config')

function OrgHighlighter:new()
  local data = {
    namespace = vim.api.nvim_create_namespace('org_custom_highlighter'),
    buffers = {},
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

function OrgHighlighter:_on_win(_, _, bufnr, topline, botline)
  local is_org_buffer = vim.bo[bufnr].filetype == 'org'
  if not is_org_buffer then
    return false
  end
  local parsed_trees = {}
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { language_tree = vim.treesitter.get_parser(bufnr, 'org') }
    parsed_trees = self.buffers[bufnr].language_tree:parse()
    self.buffers[bufnr].language_tree:register_cbs({
      on_detach = function(buf)
        self:_on_detach(buf)
      end,
    })
  else
    parsed_trees = self.buffers[bufnr].language_tree:parse({ topline, botline + 1 })
  end
  self.buffers[bufnr].tree = parsed_trees and parsed_trees[1]
end

function OrgHighlighter:_on_line(_, _, bufnr, line)
  if self.buffers[bufnr].tree then
    self.markup:on_line(bufnr, line, self.buffers[bufnr].tree)
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
