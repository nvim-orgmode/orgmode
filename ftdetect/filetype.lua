if vim.fn.has('nvim-0.7') ~= 1 then
  if vim.filetype then
    vim.filetype.add({
      extension = {
        org = 'org',
        org_archive = 'org',
      },
    })
  end
end
