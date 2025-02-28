(timestamp "<") @org.timestamp.active
(timestamp "[") @org.timestamp.inactive
(headline (item) @spell)
(headline (stars) @stars (#org-is-headline-level? @stars "1")) @org.headline.level1
(headline (stars) @stars (#org-is-headline-level? @stars "2")) @org.headline.level2
(headline (stars) @stars (#org-is-headline-level? @stars "3")) @org.headline.level3
(headline (stars) @stars (#org-is-headline-level? @stars "4")) @org.headline.level4
(headline (stars) @stars (#org-is-headline-level? @stars "5")) @org.headline.level5
(headline (stars) @stars (#org-is-headline-level? @stars "6")) @org.headline.level6
(headline (stars) @stars (#org-is-headline-level? @stars "7")) @org.headline.level7
(headline (stars) @stars (#org-is-headline-level? @stars "8")) @org.headline.level8
(item . (expr) @org.keyword.todo @nospell (#org-is-todo-keyword? @org.keyword.todo "TODO"))
(item . (expr) @org.keyword.done @nospell (#org-is-todo-keyword? @org.keyword.done "DONE"))
(item priority: (priority) @org.priority.highest (#org-is-valid-priority? @org.priority.highest "highest"))
(item priority: (priority) @org.priority.high (#org-is-valid-priority? @org.priority.high "high"))
(item priority: (priority) @org.priority.default (#org-is-valid-priority? @org.priority.default "default"))
(item priority: (priority) @org.priority.low (#org-is-valid-priority? @org.priority.low "low"))
(item priority: (priority) @org.priority.lowest (#org-is-valid-priority? @org.priority.lowest "lowest"))
(list (listitem (paragraph) @spell))
(body (paragraph) @spell)
(bullet) @org.bullet
(checkbox) @org.checkbox
(checkbox status: (expr "-") @org.checkbox.halfchecked)
(checkbox status: (expr "str") @org.checkbox.checked (#any-of? @org.checkbox.checked "x" "X"))
(block "#+begin_" @org.block "#+end_" @org.block)
(inline_code_block open: (open) @org.inline_block close: (close) @org.inline_block)
(block name: (expr) @org.block)
(block end_name: (expr) @org.block)
(block parameter: (expr) @org.block)
(dynamic_block name: (expr) @org.block)
(dynamic_block end_name: (expr) @org.block)
(dynamic_block parameter: (expr) @org.block)
(property_drawer (property name: (expr) @org.properties.name)) @org.properties
(latex_env) @org.latex_env
(drawer) @org.drawer
(tag_list) @org.tag
(directive name: (expr) @_directive_name value: (value) @org.tag (#match? @_directive_name "\\c^filetags$"))
(plan) @org.plan
(comment) @org.comment @spell
(directive) @org.directive
(row "|" @org.table.delimiter)
(cell "|" @org.table.delimiter)
(table (row (cell (contents) @org.table.heading)))
(table (hr) @org.table.delimiter)
(fndef label: (expr) @org.footnote (#offset! @org.footnote 0 -4 0 1))
(link) @org.hyperlink
(link_desc) @org.hyperlink
(link "[[" @_link_open "]]" @_link_close (#set! conceal ""))
(link_desc "[[" @_link_open "][" @_link_separator "]]" @_link_close (#set! conceal ""))
((link_desc url: (expr)+ @_link_url (#set! @_link_url conceal "")) @_link (#set! @_link url @_link_url))
