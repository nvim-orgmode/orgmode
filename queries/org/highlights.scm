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
 (bullet) @OrgTSBullet
(listitem . (bullet) . (paragraph . (expr "[" "str" @OrgCheckDone "]") @OrgTSCheckboxChecked (#match? @OrgTSCheckboxChecked "\[[xX]\]")))
(listitem . (bullet) . (paragraph . (expr "[" "-" @OrgCheckInProgress "]") @OrgTSCheckboxHalfChecked (#eq? @OrgTSCheckboxHalfChecked "[-]")))
(listitem . (bullet) . (paragraph . ((expr "[") @OrgTSCheckbox.left (#eq? @OrgTSCheckbox.left "[") . (expr "]") @OrgTSCheckbox.right (#eq? @OrgTSCheckbox.right "]"))))
(block "#+begin_" @OrgTSBlock "#+end_" @OrgTSBlock "str" @OrgTSBlock)
(block name: (expr) @OrgTSBlock)
(block parameter: (expr) @OrgTSBlock)
 (property_drawer) @OrgTSPropertyDrawer
 (drawer) @OrgTSDrawer
 (tag) @OrgTSTag
 (plan) @OrgTSPlan
 (comment) @OrgTSComment
 (directive) @OrgTSDirective
(ERROR) @LspDiagnosticsUnderlineError
