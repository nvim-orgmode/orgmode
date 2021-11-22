((timestamp) @timestamp (#match? @timestamp "^\\<.*$")) @OrgTSTimestampActive
((timestamp) @timestamp_inactive (#match? @timestamp_inactive "^\\[.*$")) @OrgTSTimestampInactive
(headline (stars) @stars (#eq? @stars "*")) @OrgTSHeadlineLevel1
(headline (stars) @stars (#eq? @stars "**")) @OrgTSHeadlineLevel2
(headline (stars) @stars (#eq? @stars "***")) @OrgTSHeadlineLevel3
(headline (stars) @stars (#eq? @stars "****")) @OrgTSHeadlineLevel4
(headline (stars) @stars (#eq? @stars "*****")) @OrgTSHeadlineLevel5
(headline (stars) @stars (#eq? @stars "******")) @OrgTSHeadlineLevel6
(headline (stars) @stars (#eq? @stars "*******")) @OrgTSHeadlineLevel7
(headline (stars) @stars (#eq? @stars "********")) @OrgTSHeadlineLevel8
(subscript) @OrgTSSubscript
(superscript) @OrgTSSuperscript
(bullet) @OrgTSBullet
(checkbox) @OrgTSCheckbox
((checkbox) @check (#eq? @check "\[-\]")) @OrgTSCheckboxHalfChecked
((checkbox) @check (#eq? @check "\[ \]")) @OrgTSCheckboxUnchecked
((checkbox) @check (#match? @check "\[[xX]\]")) @OrgTSCheckboxChecked
(property_drawer) @OrgTSPropertyDrawer
(drawer) @OrgTSDrawer
(tag) @OrgTSTag
(plan) @OrgTSPlan
(comment) @OrgTSComment
(directive) @OrgTSDirective
(ERROR) @LspDiagnosticsUnderlineError
