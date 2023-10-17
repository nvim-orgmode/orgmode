(timestamp "<") @OrgTSTimestampActive
(timestamp "[") @OrgTSTimestampInactive
(headline (stars) @stars (#eq? @stars "*")) @OrgTSHeadlineLevel1
(headline (stars) @stars (#eq? @stars "**")) @OrgTSHeadlineLevel2
(headline (stars) @stars (#eq? @stars "***")) @OrgTSHeadlineLevel3
(headline (stars) @stars (#eq? @stars "****")) @OrgTSHeadlineLevel4
(headline (stars) @stars (#eq? @stars "*****")) @OrgTSHeadlineLevel5
(headline (stars) @stars (#eq? @stars "******")) @OrgTSHeadlineLevel6
(headline (stars) @stars (#eq? @stars "*******")) @OrgTSHeadlineLevel7
(headline (stars) @stars (#eq? @stars "********")) @OrgTSHeadlineLevel8
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
