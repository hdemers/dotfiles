" Syntax highlighting for jujutsu show/diff output
if exists('b:current_syntax')
  finish
endif

" Header section (before diff)
syn match jjHeaderLabel "^Commit ID:" nextgroup=jjCommitHash skipwhite
syn match jjHeaderLabel "^Change ID:" nextgroup=jjChangeId skipwhite
syn match jjHeaderLabel "^Author\s*:" nextgroup=jjAuthor skipwhite
syn match jjHeaderLabel "^Committer:" nextgroup=jjAuthor skipwhite
syn match jjHeaderLabel "^Bookmarks:" nextgroup=jjBookmarks skipwhite
syn match jjHeaderLabel "^Tags:" nextgroup=jjTags skipwhite

" Values
syn match jjCommitHash "\x\{40\}" contained
syn match jjChangeId "[a-z]\{32\}" contained
syn match jjAuthor ".*$" contained contains=jjEmail,jjDate
syn match jjBookmarks ".*$" contained
syn match jjTags ".*$" contained
syn match jjEmail "<[^>]\+>"
syn match jjDate "\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\}:\d\{2\}"

" Diff content
syn match jjDiffFile "^diff --git.*$"
syn match jjDiffIndex "^index \x\+\.\.\x\+.*$"
syn match jjDiffOldFile "^--- .*$"
syn match jjDiffNewFile "^+++ .*$"
syn match jjDiffHunk "^@@.*@@"
syn match jjDiffAdd "^+.*$"
syn match jjDiffDel "^-.*$"
syn match jjDiffContext "^ .*$"

" Highlighting
hi def link jjHeaderLabel Statement
hi def link jjCommitHash Identifier
hi def link jjChangeId Identifier
hi def link jjAuthor String
hi def link jjEmail Special
hi def link jjDate Comment
hi def link jjBookmarks Type
hi def link jjTags Constant

hi def link jjDiffFile Title
hi def link jjDiffIndex Comment
hi def link jjDiffOldFile DiffDelete
hi def link jjDiffNewFile DiffAdd
hi def link jjDiffHunk Function
hi def link jjDiffAdd DiffAdd
hi def link jjDiffDel DiffDelete
hi def link jjDiffContext Normal

let b:current_syntax = 'jujutsu'
