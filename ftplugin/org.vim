lua require('orgmode.config'):setup_mappings('org')
setlocal omnifunc=v:lua.orgmode.omni
setlocal commentstring=#\ %s
inoreabbrev <silent><buffer> :today: <<C-R>=luaeval("require('orgmode.objects.date').today():to_string()")<CR>>
inoreabbrev <silent><buffer> :now: <<C-R>=luaeval("require('orgmode.objects.date').now():to_string()")<CR>>
