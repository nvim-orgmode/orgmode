(timestamp "<") @OrgTSTimestampActive
(timestamp "[") @OrgTSTimestampInactive
(headline (stars) @text.title.1.marker (#eq? @text.title.1.marker "*")) @text.title.1
(headline (stars) @text.title.2.marker (#eq? @text.title.2.marker "**")) @text.title.2
(headline (stars) @text.title.3.marker (#eq? @text.title.3.marker "***")) @text.title.3
(headline (stars) @text.title.4.marker (#eq? @text.title.4.marker "****")) @text.title.4
(headline (stars) @text.title.5.marker (#eq? @text.title.5.marker "*****")) @text.title.5
(headline (stars) @text.title.6.marker (#eq? @text.title.6.marker "******")) @text.title.6
(headline (stars) @text.title.7.marker (#eq? @text.title.7.marker "*******")) @text.title.7
(headline (stars) @text.title.8.marker (#eq? @text.title.8.marker "********")) @text.title.8
(headline (item) @spell)
(item . (expr) @OrgTODO @nospell (#org-is-todo-keyword? @OrgTODO "TODO"))
(item . (expr) @OrgDONE @nospell (#org-is-todo-keyword? @OrgDONE "DONE"))
(list (listitem (paragraph) @spell))
(body (paragraph) @spell)
(bullet) @OrgTSBullet
(checkbox) @OrgTSCheckbox
(checkbox status: (expr "-") @OrgTSCheckboxHalfChecked)
(checkbox status: (expr "str") @OrgTSCheckboxChecked (#any-of? @OrgTSCheckboxChecked "x" "X"))
(block "#+begin_" @OrgTSBlock "#+end_" @OrgTSBlock)
(block name: (expr) @OrgTSBlock)
(block end_name: (expr) @OrgTSBlock)
(block parameter: (expr) @OrgTSBlock)
(dynamic_block name: (expr) @OrgTSBlock)
(dynamic_block end_name: (expr) @OrgTSBlock)
(dynamic_block parameter: (expr) @OrgTSBlock)
(property_drawer) @OrgTSPropertyDrawer
(latex_env) @OrgTSLatex
(drawer) @OrgTSDrawer
(tag_list) @OrgTSTag
(plan) @OrgTSPlan
(comment) @OrgTSComment @spell
(directive) @OrgTSDirective
