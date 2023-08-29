if exists("b:current_syntax")
  finish
endif

" inclue sql syntax
runtime! syntax/sql.vim

unlet b:current_syntax

" set region for jinja syntax
syntax include @jinja syntax/jinja.vim
" syntax region JinjaEmbedded start=/{[{#\%\[]/ skip="(\/\*|\*\/|--)" end=/[}#\%\]]}/ contains=@jinja
syntax region JinjaEmbedded start=/{[{%#]/ skip="(\/\*|\*\/|--)" end=/[%#}]}/ contains=@jinja
syntax region JinjaEmbedded start="{%" end="%}" contains=@jinja
" syntax region JinjaEmbedded start=/{!/ end=/!}/ contains=@jinja
" syntax match JinjaEmbedded /\s*#.*$/ contains=@jinja

" syn region sqlComment       start="/\*" end="\*/"
" syn match  sqlComment       "-- .*$"

let b:current_syntax='jinja-sql'

