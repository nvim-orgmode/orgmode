(timestamp "<") @org.timestamp.active
(timestamp "[") @org.timestamp.inactive
(headline (stars) @stars (#eq? @stars "*")) @org.headline.level1
(headline (stars) @stars (#eq? @stars "**")) @org.headline.level2
(headline (stars) @stars (#eq? @stars "***")) @org.headline.level3
(headline (stars) @stars (#eq? @stars "****")) @org.headline.level4
(headline (stars) @stars (#eq? @stars "*****")) @org.headline.level5
(headline (stars) @stars (#eq? @stars "******")) @org.headline.level6
(headline (stars) @stars (#eq? @stars "*******")) @org.headline.level7
(headline (stars) @stars (#eq? @stars "********")) @org.headline.level8
(headline (item) @spell)
(item . (expr) @org.keyword.todo @nospell (#org-is-todo-keyword? @org.keyword.todo "TODO"))
(item . (expr) @org.keyword.done @nospell (#org-is-todo-keyword? @org.keyword.done "DONE"))
(item (expr "[" "#" "str" @_priority "]") @org.priority.highest (#org-is-valid-priority? @_priority "highest"))
(item (expr "[" "#" "str" @_priority "]") @org.priority.default (#org-is-valid-priority? @_priority "default"))
(item (expr "[" "#" "str" @_priority "]") @org.priority.lowest (#org-is-valid-priority? @_priority "lowest"))
(list (listitem (paragraph) @spell))
(body (paragraph) @spell)
(bullet) @org.bullet
(checkbox) @org.checkbox
(checkbox status: (expr "-") @org.checkbox.halfchecked)
(checkbox status: (expr "str") @org.checkbox.checked (#any-of? @org.checkbox.checked "x" "X"))
(block "#+begin_" @org.block "#+end_" @org.block)
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
(table
  (row (cell (contents) @org.table.heading))
  (hr) @org.table.delimiter
)
