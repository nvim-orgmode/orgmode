syntax match orghelp_key /`[^`]*`/ contains=orghelp_backtick
syntax match orghelp_bold /^\s*\*\*[^\*]*\*\*$/ contains=orghelp_asterisk
syntax match orghelp_bold_italic /^\s*__[^_]*__$/ contains=orghelp_underscore
syntax match orghelp_backtick /`/ cchar= conceal contained
syntax match orghelp_asterisk /\*\*/ cchar= conceal contained
syntax match orghelp_underscore /__/ cchar= conceal contained

hi def orghelp_bold gui=bold cterm=bold term=bold
hi def orghelp_bold_italic gui=bold,italic cterm=bold,italic term=bold,italic
hi def link orghelp_key Identifier
