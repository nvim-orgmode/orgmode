nnoremap <Plug>(org-agenda-next-span) <cmd>lua require('orgmode').action('agenda.advance_span', 1)<CR>
nnoremap <Plug>(org-agenda-prev-span) <cmd>lua require('orgmode').action('agenda.advance_span', -1)<CR>
nnoremap <Plug>(org-agenda-reset-span) <cmd>lua require('orgmode').action('agenda.reset')<CR>

nmap <nowait><silent><buffer>f <Plug>(org-agenda-next-span)
nmap <nowait><silent><buffer>b <Plug>(org-agenda-prev-span)
nmap <nowait><silent><buffer>. <Plug>(org-agenda-reset-span)
nmap <nowait><silent><buffer>vd <cmd>lua require('orgmode').action('agenda.change_span', 'day')<CR>
nmap <nowait><silent><buffer>vw <cmd>lua require('orgmode').action('agenda.change_span', 'week')<CR>
nmap <nowait><silent><buffer>vm <cmd>lua require('orgmode').action('agenda.change_span', 'month')<CR>
nmap <nowait><silent><buffer>vy <cmd>lua require('orgmode').action('agenda.change_span', 'year')<CR>
nnoremap <nowait><silent><buffer>q :bw!<CR>
