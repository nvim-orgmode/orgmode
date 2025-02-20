 (block parameter: (expr) @_lang (contents) @injection.content (#set! injection.include-children) (#org-set-block-language! @_lang))
 (latex_env (contents) @injection.content (#set! injection.include-children) (#set! injection.language "tex"))
((paragraph) @injection.content
  (#set! injection.language "org_inline")
  (#set! injection.include-children)
)
