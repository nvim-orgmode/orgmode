if exists('b:current_syntax')
  finish
endif

runtime! syntax/org.vim
unlet! b:current_syntax

let b:current_syntax = 'orgcapture'
