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

function ls_style_to_octal(rwx_string)
  local result = 0
  local value = 0

  for i = 1, #rwx_string, 3 do
    local chunk = rwx_string:sub(i, i+2)
    value = 0

    if chunk:sub(1, 1) == 'r' then value = value + 4 end
    if chunk:sub(2, 2) == 'w' then value = value + 2 end
    if chunk:sub(3, 3) == 'x' then value = value + 1 end

    result = result * 8 + value
  end

  return result
end


function chmod_style_to_octal(chmod_string)
  local owner, group, other = 0, 0, 0

  for part in chmod_string:gmatch('[^,]+') do
    local who, what = part:match('(%a+)[=+](.+)')
    if not who or not what then
      return nil
    end


    local perm = 0
    if what:find('r') then perm = perm + 4 end
    if what:find('w') then perm = perm + 2 end
    if what:find('x') then perm = perm + 1 end

    if who:find('u') or who:find('a') then owner = bit.bor(owner, perm) end
    if who:find('g') or who:find('a') then group = bit.bor(group, perm) end
    if who:find('o') or who:find('a') then other = bit.bor(other, perm) end
  end

  return owner * 64 + group * 8 + other
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
      tangle_info[info.filename] = { content = {} }
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
        filemode = 'o755'
      end
    end

    local tangle_mode = info.header_args[':tangle-mode']
    if tangle_mode then
      filemode = tangle_mode:gsub('[\'"]', '')
    end

    if info.header_args[':mkdirp'] == 'yes' then
      local path = vim.fn.fnamemodify(info.filename, ':h')
      vim.fn.mkdir(path, 'p')
    end

    if info.name then
      block_content_by_name[info.name] = parsed_content
    end
    vim.list_extend(tangle_info[info.filename]['content'], parsed_content)
    tangle_info[info.filename]['mode'] = filemode
  end

  local promises = {}
  for filename, block in pairs(tangle_info) do

    table.insert(
      promises,
      utils.writefile(filename, table.concat(self:_remove_obsolete_indent(block['content']), '\n'))
    )

    local mode_str = block['mode']
    local mode = nil

    if mode_str and mode_str:sub(1, 1) == 'o' then
      mode = tonumber(mode_str:sub(2), 8)
    else
      mode = chmod_style_to_octal(mode_str)
      if mode == nil then
        mode = ls_style_to_octal(mode_str)
      end
    end

    if mode then
      utils.echo_info(('change mode %s mode %o'):format(filename, mode))
      vim.loop.fs_chmod(filename, mode)
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
