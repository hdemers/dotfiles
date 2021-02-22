" inclue sql syntax
runtime! syntax/sql.vim

" unlet b:current_syntax

" set region for jinja syntax
syntax include @jinja syntax/jinja.vim
syntax region jinjaSyntax start=/{[{#\%\[]/ skip="(\/\*|\*\/|--)" end=/[}#\%\]]}/ contains=@jinja
syntax match jinjaSyntax /#.*/ contains=@jinja

" let b:current_syntax='jinja-sql'
