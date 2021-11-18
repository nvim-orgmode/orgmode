((timestamp) @timestamp (#match? @timestamp "^\\<.*$")) @OrgTSTimestampActive
((timestamp) @timestamp_inactive (#match? @timestamp_inactive "^\\[.*$")) @OrgTSTimestampInactive
; ((markup) @markup_bold (#match? @markup_bold "^\\s*\\*.*\\*$")) @text.strong
; ((markup) @markup_italic (#match? @markup_italic "^\\s*\\/.*\\/$")) @text.emphasis
; ((markup) @markup_underline (#match? @markup_underline "^\\s*_.*_$")) @TSUnderline
; ((markup) @markup_code (#match? @markup_code "^\\s*\\~.*\\~$")) @String
; ((markup) @markup_verbatim (#match? @markup_verbatim "^\\s*\\=.*\\=$")) @String
; ((markup) @markup_strike (#match? @markup_strike "^\\s*\\+.*\\+$")) @text.strike
(headline (stars) @stars (#eq? @stars "*")) @OrgTSHeadlineLevel1
(headline (stars) @stars (#eq? @stars "**")) @OrgTSHeadlineLevel2
(headline (stars) @stars (#eq? @stars "***")) @OrgTSHeadlineLevel3
(headline (stars) @stars (#eq? @stars "****")) @OrgTSHeadlineLevel4
(headline (stars) @stars (#eq? @stars "*****")) @OrgTSHeadlineLevel5
(headline (stars) @stars (#eq? @stars "******")) @OrgTSHeadlineLevel6
(headline (stars) @stars (#eq? @stars "*******")) @OrgTSHeadlineLevel7
(headline (stars) @stars (#eq? @stars "********")) @OrgTSHeadlineLevel8
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
