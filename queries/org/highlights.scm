((timestamp) @timestamp (#match? @timestamp "^\\<.*$")) @PreProc
((timestamp) @timestamp_inactive (#match? @timestamp_inactive "^\\[.*$")) @Comment
; ((markup) @markup_bold (#match? @markup_bold "^\\s*\\*.*\\*$")) @text.strong
; ((markup) @markup_italic (#match? @markup_italic "^\\s*\\/.*\\/$")) @text.emphasis
; ((markup) @markup_underline (#match? @markup_underline "^\\s*_.*_$")) @TSUnderline
; ((markup) @markup_code (#match? @markup_code "^\\s*\\~.*\\~$")) @String
; ((markup) @markup_verbatim (#match? @markup_verbatim "^\\s*\\=.*\\=$")) @String
; ((markup) @markup_strike (#match? @markup_strike "^\\s*\\+.*\\+$")) @text.strike
(headline (stars) @stars (#eq? @stars "*")) @OrgHeadlineLevel1
(headline (stars) @stars (#eq? @stars "**")) @OrgHeadlineLevel2
(headline (stars) @stars (#eq? @stars "***")) @OrgHeadlineLevel3
(headline (stars) @stars (#eq? @stars "****")) @OrgHeadlineLevel4
(headline (stars) @stars (#eq? @stars "*****")) @OrgHeadlineLevel5
(headline (stars) @stars (#eq? @stars "******")) @OrgHeadlineLevel6
(headline (stars) @stars (#eq? @stars "*******")) @OrgHeadlineLevel7
(headline (stars) @stars (#eq? @stars "********")) @OrgHeadlineLevel8
(bullet) @Identifier
(checkbox) @PreProc
(property_drawer) @Constant
(tag) @Function
(plan) @Constant
(comment) @Comment
(directive) @Comment
(ERROR) @LspDiagnosticsUnderlineError
