lua require('orgmode.config'):setup_mappings('org')
inoreabbrev <buffer> :today: <<C-R>=luaeval("require('orgmode.objects.date').today():to_string()")<CR>>
inoreabbrev <buffer> :now: <<C-R>=luaeval("require('orgmode.objects.date').now():to_string()")<CR>>
