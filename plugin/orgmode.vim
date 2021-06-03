if exists('g:loaded_orgmode_nvim')
  finish
end

let g:loaded_orgmode_nvim = 1

" Temporarily autoload something
lua require('orgmode').setup({ org_agenda_files = '~/Dropbox/org/*', org_default_notes_file = '~/Dropbox/org/refile.org' })
