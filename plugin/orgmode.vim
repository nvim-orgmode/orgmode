if exists('g:loaded_orgmode_nvim')
  finish
end

let g:loaded_orgmode_nvim = 1

" Temporarily autoload something
lua require('orgmode').setup({ org_agenda_files = '~/orgmodes/*', org_default_notes_file = '~/orgmodes/refile.org' })

nnoremap <Plug>(org-agenda-open) <cmd>lua require('orgmode').action('agenda.open')<CR>

nmap <leader>oa <Plug>(org-agenda-open)
