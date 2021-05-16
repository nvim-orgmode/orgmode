local uv = vim.loop
local utils = {}

function utils.readfile(file, callback)
  uv.fs_open(file, 'r', 438, function(err1, fd)
    if err1 then return callback(err1) end
    uv.fs_fstat(fd, function(err2, stat)
    if err2 then return callback(err2) end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then return callback(err3) end
        uv.fs_close(fd, function(err4)
          if err4 then return callback(err4) end
          local lines = vim.split(data, '\n')
          table.remove(lines, #lines)
          return callback(nil, lines)
        end)
      end)
    end)
  end)
end

function utils.echo_warning(msg)
  vim.cmd[[echohl WarningMsg]]
  vim.cmd('echom '..msg)
  vim.cmd[[echohl None]]
end

return utils
