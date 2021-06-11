syntax match orghelp_key /`[^`]*`/ contains=orghelp_backtick
syntax match orghelp_bold /^\s*Orgmode mappings:$/
syntax match orghelp_backtick /`/ cchar= conceal contained

hi def orghelp_bold gui=bold cterm=bold term=bold
hi def link orghelp_key Identifier
