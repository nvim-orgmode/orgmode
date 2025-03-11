local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

---@class OrgBabelTangle
---@field file OrgFile
local Tangle = {}
Tangle.__index = Tangle

---@param opts { file: OrgFile }
---@return OrgBabelTangle
function Tangle:new(opts)
  return setmetatable({
    file = opts.file,
  }, self)
end

function Tangle:tangle()
  local block_content_by_name = {}
  ---@type OrgBlockTangleInfo[]
  local valid_blocks = {}

  for _, block in ipairs(self.file:get_blocks()) do
    if block:is_src_block() then
      local info = block:get_tangle_info()
      if info.name and not block_content_by_name[info.name] then
        block_content_by_name[info.name] = info.content
      end
      if info.tangle then
        table.insert(valid_blocks, info)
      end
    end
  end

  local tangle_info = {}

  for _, info in ipairs(valid_blocks) do
    if tangle_info[info.filename] then
      table.insert(tangle_info[info.filename]['content'], '')
    else
      tangle_info[info.filename] = {content = {}}
    end

    local filemode = tangle_info[info.filename]['mode']
    local do_noweb = info.header_args[':noweb'] == 'yes' or info.header_args[':noweb'] == 'tangle'
    local parsed_content = info.content

    if do_noweb then
      parsed_content = {}
      for _, line in ipairs(info.content) do
        local noweb_ref = line:match('^%s*<<(.*)>>%s*$')
        if noweb_ref then
          vim.list_extend(parsed_content, block_content_by_name[noweb_ref] or {})
        else
          table.insert(parsed_content, line)
        end
      end
    end

    if info.header_args[':mkdirp'] == 'yes' then
      local path = vim.fn.fnamemodify(info.filename, ':h')
      vim.fn.mkdir(path, 'p')
    end

    local shebang = info.header_args[':shebang']
    if shebang then
      shebang = shebang:gsub('[\'"]', '')
      table.insert(parsed_content, 1, shebang)
      if filemode == nil then
        filemode = "o755"
      end
    end

    local tangle_mode = info.header_args[':tangle-mode']
    if tangle_mode then
      filemode = tangle_mode:gsub('[\'"]', '')
    end

    if info.name then
      block_content_by_name[info.name] = parsed_content
    end
    vim.list_extend(tangle_info[info.filename]['content'], parsed_content)
    tangle_info[info.filename]['mode'] = filemode
  end

  local promises = {}
  for filename, block in pairs(tangle_info) do
    table.insert(promises, utils.writefile(filename, table.concat(self:_remove_obsolete_indent(block['content']), '\n')))
    local mode_str = block['mode']
    if mode_str and mode_str:sub(1, 1) == 'o' then
      mode_str = mode_str:sub(2)
      local mode_num = tonumber(mode_str, 8)
      vim.loop.fs_chmod(filename, mode_num)
    end
  end
  Promise.all(promises):wait()
  utils.echo_info(('Tangled %d blocks from %s'):format(#valid_blocks, vim.fn.fnamemodify(self.file.filename, ':t')))
end

function Tangle:_remove_obsolete_indent(content)
  local dedent_amount = nil
  for _, line in ipairs(content) do
    if vim.trim(line) ~= '' then
      local _, indent = line:find('^%s*')
      if not dedent_amount then
        dedent_amount = indent or 0
      else
        dedent_amount = math.min(dedent_amount, indent)
      end
    end
  end
  if not dedent_amount or dedent_amount == 0 then
    return content
  end
  return vim.tbl_map(function(line)
    return line:sub(dedent_amount + 1)
  end, content)
end

return Tangle
