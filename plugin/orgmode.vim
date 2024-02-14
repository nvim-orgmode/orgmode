" Wrapper around input() function that allows providing custom completion function
" @see https://github.com/neovim/neovim/issues/16301#issuecomment-968247015
function! OrgmodeInput(prompt, default, ...) abort
  if a:0 > 0
    return input(a:prompt, a:default, 'customlist,'..get(a:1, 'name'))
  endif
  return input(a:prompt, a:default)
endfunction

function OrgmodeWatchDictChanges(dict, key, change_dict) abort
  return luaeval('require("orgmode.utils.dict_watcher").dict_changed(_A[1], _A[2], _A[3])', [a:change_dict, a:key, a:dict])
endfunction
