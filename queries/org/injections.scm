 (block parameter: (expr) @_lang (contents) @injection.content (#set! injection.include-children) (#org-set-block-language! @_lang))
 ; (inline_code_block language: (language) @_lang contents: (contents) @injection.content (#set! injection.include-children) (#org-set-block-language! @_lang))
 (latex_env (contents) @injection.content (#set! injection.include-children) (#set! injection.language "tex"))
