"=====================================================================
" File: ~/.vim/plugin/map_abbr.vim
" Author: Hugues Demers
"=====================================================================

"=====================================================================
" Mappings and Abbreviations
"=====================================================================

map <Leader>z :b #<CR>
map <Leader>q :bd<CR>
map <C-s> :write<CR>
nnoremap <Leader>/ :nohlsearch<CR>
map <Leader>w :set wrap<CR>
map <Leader>W :set nowrap<CR>
map <Leader>d :vertical diffsplit 
map <Leader>D :set nodiff \| set foldcolumn=0 \| set noscb<CR>
map <Tab> %

"Moving around mappings
map <M-Up> <C-W><Up>
map <M-Down> <C-W><Down>
map <M-Left> <C-W><Left>
map <M-Right> <C-W><Right>
map <C-Up> <C-y>
map <C-Down> <C-e>
map <S-Up> <C-W>+
map <S-Down> <C-W>-
map <S-Left> <C-W><
map <S-Right> <C-W>>
map <C-Right> w
map <C-Left> b

" Mapping that work in insert mode
map! <C-s> <ESC>:write<CR>
map! <C-Up> <C-y>
map! <C-Down> <C-e>
map! <M-z> <ESC>:A<CR>

" Mapping to enable/disable spell checking.
map <Leader>s :set spell<CR>
map <Leader>S :set nospell<CR>

" Searching using Git
map <Leader>g :Ggrep <cword><CR>

" Syntastic mapping
map <Leader>y :SyntasticToggleMode<CR>

" Mapping of function keys
map <F1> :Explore<CR>
map <F2> :BufExplorer<CR>
map <F3> :TagbarToggle<CR>
map <F6> :Gstatus<CR>
map <F7> :Gdiff<CR>
map <F8> :Gcommit<CR>
map <F9> :GundoToggle<CR>


inoremap <C-E> <C-X><C-E>
inoremap <C-Y> <C-X><C-Y>

" Command-T mappings

