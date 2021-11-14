" Wrapper around input() function that allows providing custom completion function
" @see https://github.com/neovim/neovim/issues/16301#issuecomment-968247015
function! OrgmodeInput(prompt, default, ...) abort
  if a:0 > 0
    return input(a:prompt, a:default, 'customlist,'..get(a:1, 'name'))
  endif
  return input(a:prompt, a:default)
endfunction
