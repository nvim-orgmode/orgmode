lua require('orgmode.config'):setup_mappings('org')
function OrgmodeOmni(findstart, base)
  return luaeval('require("orgmode.org.autocompletion").omni(_A[1], _A[2])', [a:findstart, a:base])
endfunction

setlocal omnifunc=OrgmodeOmni
setlocal commentstring=#\ %s
inoreabbrev <silent><buffer> :today: <<C-R>=luaeval("require('orgmode.objects.date').today():to_string()")<CR>>
inoreabbrev <silent><buffer> :now: <<C-R>=luaeval("require('orgmode.objects.date').now():to_string()")<CR>>
