" set guifont=Ubuntu\ Mono\ 11
set guifont=Hack\ Regular\ 9
" set guifont=Fira\ Code\ Regular\ 9
" set guifont=Sudo\ Medium\ 12


"=====================================================================
" Load plugins using plug.vim (https://github.com/junegunn/vim-plug)
"=====================================================================
call plug#begin('~/.config/nvim/plugged')
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'chrisbra/csv.vim'
Plug 'airblade/vim-gitgutter'
Plug 'ervandew/supertab'
Plug 'jlanzarotta/bufexplorer'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'majutsushi/tagbar'
Plug 'mbbill/undotree'
Plug 'lifepillar/vim-solarized8'
Plug 'rakr/vim-one'
Plug 'joshdick/onedark.vim'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-vinegar'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-dotenv'
Plug 'tpope/vim-projectionist'
Plug 'rbong/vim-flog'
Plug 'wellle/targets.vim'
Plug 'wellle/context.vim'
Plug 'mhinz/vim-startify'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'dense-analysis/ale'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-easy-align'
Plug 'raimon49/requirements.txt.vim'
Plug 'psf/black'
Plug 'jmcantrell/vim-virtualenv'
Plug 'junegunn/vim-peekaboo'
Plug 'sheerun/vim-polyglot'
Plug 'ruanyl/vim-gh-line'
Plug 'nathangrigg/vim-beancount'
Plug 'vim-test/vim-test'
" TODO: with neomake, I'm not sure I need asyncrun anymore. Test it.
Plug 'skywind3000/asyncrun.vim'
Plug 'skywind3000/asynctasks.vim'
Plug 'kenn7/vim-arsync'
Plug 'prabirshrestha/async.vim' " vim-arsync dependency.
Plug 'rhysd/clever-f.vim'
Plug 'markonm/traces.vim'
" Plug 'prabirshrestha/vim-lsp'
" Plug 'mattn/vim-lsp-settings'
Plug 'github/copilot.vim'
Plug 'quarto-dev/quarto-vim'
Plug 'vim-pandoc/vim-pandoc-syntax'
Plug 'voldikss/vim-floaterm'
Plug 'luizribeiro/vim-cooklang'
if has('python3')
    Plug 'madox2/vim-ai'
    Plug 'puremourning/vimspector'
    Plug 'obreitwi/vim-sort-folds'
    Plug 'davidhalter/jedi-vim'
endif
" NeoVim packages
Plug 'andythigpen/nvim-coverage'
Plug 'nvim-lua/plenary.nvim' " nvim-coverage dependency.
Plug 'neomake/neomake'
Plug 'CarloDePieri/vim-pytest'
Plug 'kevinhwang91/nvim-bqf'
call plug#end()

"=====================================================================
" Colors and syntax highlighting.
"=====================================================================
if exists('+termguicolors')
  set termguicolors
endif

let python_highlight_all = 1
syntax enable
set background=dark
colorscheme solarized8_flat

"=====================================================================
" Various settings
"=====================================================================
let mapleader = ' '

filetype on
filetype plugin indent on

set expandtab
"Don't ignore case when there is an upper case character in the pattern. For
"smartcase to take effect, ignorecase must be on.
set ignorecase
set smartcase
" Set wrapping of cursor movement
set whichwrap=b,s,<,>,[,]
" Do not wrap lines
set nowrap
" Set the text width
set textwidth=79
" Persist undo history
set undofile
" 'showmode' must be disabled for Jedi command line call signatures to be
" visible.
set noshowmode
" Always show the sign column
set signcolumn=yes
" Allows italics to be properly shown in terminals, especially tmux.
" set t_ZH=[3m
" set t_ZR=[23m

" Use a line cursor within insert mode and a block cursor everywhere else.
" let &t_SI = "\e[6 q"
" let &t_EI = "\e[2 q"

"=====================================================================
" Plugins
"=====================================================================

" My custom lua config
lua require('myconfig')

" BufExplorer
let g:bufExplorerShowRelativePath=1

" SuperTab
" let g:SuperTabDefaultCompletionType = "context"

" Tagbar
let g:tagbar_autoclose = 1
let g:tagbar_compact = 0
let g:tagbar_show_visibility = 0
let g:tagbar_iconchars = ['+', '-']
let g:tagbar_left = 1
" let g:tagbar_show_balloon = 0
" let g:tagbar_scopestrs = {
"     \    'class': "\uf0e8",
"     \    'const': "\uf8ff",
"     \    'constant': "\uf8ff",
"     \    'enum': "\uf702",
"     \    'field': "\uf30b",
"     \    'func': "\uf794",
"     \    'function': "\uf794",
"     \    'getter': "\ufab6",
"     \    'implementation': "\uf776",
"     \    'interface': "\uf7fe",
"     \    'map': "\ufb44",
"     \    'member': "\uf02b",
"     \    'method': "\uf6a6",
"     \    'setter': "\uf7a9",
"     \    'variable': "\uf71b",
"     \ }

" Airline
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_sep = ''
let g:airline_left_alt_sep = '|'
let g:airline_right_sep = ''
let g:airline_right_alt_sep = '|'
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.dirty=' !'
let g:airline_symbols.spell = 'Ꞩ'
let g:airline_symbols.notexists = 'Ɇ'
let g:airline_symbols.crypt = '🔒'
" Only show the file encoding if it differs from utf-8[unix]
let g:airline#parts#ffenc#skip_expected_string='utf-8[unix]'
let g:airline#extensions#virtualenv#enabled = 1
let g:airline_section_z = airline#section#create(['%l:%c'])
let g:airline_skip_empty_sections = 1
let g:airline_mode_map = {
    \ '__'     : '-',
    \ 'c'      : 'C',
    \ 'i'      : 'I',
    \ 'ic'     : 'I',
    \ 'ix'     : 'I',
    \ 'n'      : 'N',
    \ 'multi'  : 'M',
    \ 'ni'     : 'N',
    \ 'no'     : 'N',
    \ 'R'      : 'R',
    \ 'Rv'     : 'R',
    \ 's'      : 'S',
    \ 'S'      : 'S',
    \ ''     : 'S',
    \ 't'      : 'T',
    \ 'v'      : 'V',
    \ 'V'      : 'V',
    \ ''     : 'V',
    \ }
let g:airline#extensions#branch#displayed_head_limit = 35
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#tab_min_count = 2
let g:airline#extensions#tabline#formatter = 'unique_tail'

"Set AsyncRun status in airline
let g:asyncrun_status = ""
let g:airline_section_error = airline#section#create_right(['%{g:asyncrun_status}'])

" Jedi
let g:jedi#completions_enabled = 0
let g:jedi#popup_on_dot = 0
let g:jedi#show_call_signatures = 2

" fzf colorscheme matching
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" ALE Python fixers
let g:ale_lsp_suggestions = 1
let g:ale_fixers = {
\   'python': ['black', 'ruff'],
\    'sql': ['remove_trailing_lines', 'trim_whitespace'],
\    'jinja-sql': ['remove_trailing_lines', 'trim_whitespace'],
\    'markdown': ['remove_trailing_lines'],
\    'beancount': ['remove_trailing_lines', 'trim_whitespace'],
\ }
" ALE Python linters
let g:ale_linters = {'python': ['ruff', 'mypy']}
" Set this variable to 1 to fix files when you save them.
let g:ale_fix_on_save = 1
" The various sign characters set below will only be shown if the following
" variable is set to 0
let g:ale_use_neovim_diagnostics_api = 0
let g:ale_sign_error = '■'
let g:ale_sign_warning = '■'
let g:ale_sign_column_always=1
let g:ale_completion_enabled = 1

" Virtualenv.vim auto activation
let g:virtualenv_auto_activate = 1

" vim-gh-line doesn't open URL, but copy to clipboard
let g:gh_open_command = 'fn() { echo "$@" | xclip -selection c -r; }; fn '
" Disable default key mappings
let g:gh_line_map_default = 0
let g:gh_line_blame_map_default = 1
let g:gh_line_map = '<leader>kl'
let g:gh_line_blame_map = '<leader>kb'

" Startify options
let g:startify_session_persistence = 1
let g:startify_session_savevars = [
    \ 'g:startify_session_savevars',
    \ 'g:startify_session_savecmds'
\ ]
let g:startify_change_to_vcs_root = 1
let g:startify_lists = [
    \ { 'type': 'sessions',  'header': ['   Sessions']       },
    \ { 'type': 'files',     'header': ['   MRU']            },
    \ { 'type': 'dir',       'header': ['   MRU '. getcwd()] },
    \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
    \ { 'type': 'commands',  'header': ['   Commands']       },
\ ]

" Undotree options
let g:undotree_SetFocusWhenToggle = 1

" Python vim-test settings
let g:test#python#runner = 'pytest'
" These options must match the errorformat defined in 
" .vim/compiler/pytest.vim for the quickfix list to work.
" let g:test#python#pytest#options = '--tb=short -q -p no:warnings'
let test#strategy = "asyncrun_background"

" vim-pytest settings
let g:pytest_airline_enabled = 0

" clever-f settings
let g:clever_f_smart_case = 1

" vim-lsp settings
let g:lsp_diagnostics_enabled = 0
let g:lsp_semantic_enabled = 1

" Vista settings
let g:vista_default_executive = 'vim_lsp'
let g:vista_fzf_preview = ['right:50%']

" Floatterm settings
let g:floaterm_keymap_toggle = '<F12>'
let g:floaterm_height = 0.85

" Ctrl-P to show hidden files
let g:ctrlp_show_hidden = 1

" context.vim is disabled by default, use :ContextToggle to enable.
let g:context_enabled = 0
"=====================================================================
" Environment variables
"=====================================================================

let $BAT_THEME='Solarized (dark)'
let $FZF_PREVIEW_COMMAND="COLORTERM=truecolor bat --style=numbers,changes --force-colorization {}"


"=====================================================================
" Functions
"=====================================================================

fun AsyncrunStatus()
    if g:asyncrun_code == 1
        let g:asyncrun_status = "☢ "
    else
        let g:asyncrun_status = ""
    endif
endfun

let g:airline_theme_patch_func = 'AirlineThemePatch'
function! AirlineThemePatch(palette)
    " Whenever the theme is set to solarized, use base16_solarized instead.
    if g:airline_theme == 'solarized'
        let g:airline_theme='base16_solarized'
    endif
endfunction

function! Highlights(...)
  redir => cout
  silent highlight
  redir END
  let s:list = split(cout, '\n')
  return fzf#run('highlights', {
  \ 'source' : s:list,
  \ 'options': '+m -x --ansi --tiebreak=index --header-lines 1 --tiebreak=begin --prompt "Highlight> "'
  \ }, a:000)
endfunction

"=====================================================================
" Autocommands
"=====================================================================

" Set syntax sync fromstart for all Python files
autocmd BufEnter *.py :syntax sync fromstart

" This is to be used with file .vim/syntax/jinja-sql.vim
" It should in theory highlight both jinja and sql syntax found in the same
" file.
autocmd BufEnter *.sql set filetype=jinja-sql

" Spell-check Markdown files and Git Commit Messages
autocmd FileType markdown setlocal spell
autocmd FileType gitcommit setlocal spell

" Restore folds in fugitive commit windows. See this issue about
" future development:
" https://github.com/tpope/vim-fugitive/issues/1735#issuecomment-822037483
autocmd User FugitiveCommit set foldmethod=syntax

" Beancount filetype setting for Supertab
autocmd FileType beancount let g:beauncount_separator_col=56
autocmd FileType beancount let b:SuperTabContextDefaultCompletionType="<c-x><c-o>"
autocmd FileType beancount VirtualEnvActivate budget

" The following setup will automatically run tests when a test file or its
" alternate application file is saved. Cf. vim-test.
augroup test
  autocmd!
  autocmd BufWrite *.py if test#exists() |
    \   PytestFile |
    \ endif
augroup END

" AsyncRun. Automatically open the quickfix window if there are error after
" running a command with AsyncRun.
" autocmd User AsyncRunStop if g:asyncrun_code > 0 | copen | endif
autocmd User AsyncRunStop call AsyncrunStatus()
autocmd User AsyncRunStart let g:asyncrun_status = '◎ '

" Remove the filetype from the X section of airline. We basically, recreate
" this section with this autocmd.
autocmd VimEnter * let g:airline_section_x = airline#section#create_right(['tagbar']) | :AirlineRefresh
" Disable tagbar integration. I want to see as much of the filename as I can
" and beside I never look at the function in the status bar.
let g:airline#extensions#tagbar#enabled = 0

"In order to recognize dvc.lock and .dvc files as YAML
autocmd! BufNewFile,BufRead Dvcfile,*.dvc,dvc.lock setfiletype yaml

" Supertab chaining: setup the supertab chaining for any filetype that has a
" provided omnifunc to first try that, then fall back to supertab's default,
" <c-p>, completion
autocmd FileType *
\ if &omnifunc != '' |
\   call SuperTabChain(&omnifunc, "<c-p>") |
\ endif

"=====================================================================
" Commands
"=====================================================================
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number -- '.shellescape(<q-args>), 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)

command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \ "rg --column --line-number --no-heading --color=always --smart-case --hidden -- ".shellescape(<q-args>),
  \ 1,
  \ fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}),
  \ <bang>0)


"=====================================================================
" Highlights
"=====================================================================
function! ALEHighlights() abort
    " highlight ALEError gui=underline cterm=underline
    " highlight ALEWarning gui=underline cterm=underline
    " highlight ALEInfo gui=underline cterm=underline
    highlight ALEErrorSign guibg=NONE ctermbg=NONE
    highlight ALEWarningSign guibg=NONE ctermbg=NONE
    highlight ALEInfoSign guibg=NONE ctermbg=NONE
    highlight ALEErrorSignLineNr guibg=NONE ctermbg=NONE
    highlight ALEWarningSignLineNr guibg=NONE ctermbg=NONE
    highlight ALEInfoSignLineNr guibg=NONE ctermbg=NONE
endfunction

function! BeancountHighlights() abort
    if g:colors_name == 'one'
        highlight link beanAccount Function
        highlight link beanDate Statement
    elseif g:colors_name == 'gruvbox'
        highlight link beanAmount Operator
        highlight link beanDate Float
    endif
endfunction

augroup MyColors
    autocmd!
    autocmd ColorScheme * call ALEHighlights()
    autocmd ColorScheme * call BeancountHighlights()
augroup END

call ALEHighlights()

" Change Copilot hightlighting
highlight! link CopilotSuggestion TabLine

" Change color of Floaterm border
hi link FloatermBorder Identifier

" Better Tagbar highlights
hi link TagbarSignature Comment
hi link TagbarHighlight Statement
hi link TagbarType Constant
"=====================================================================
" Mappings and Abbreviations
"=====================================================================
map <Leader>z :b #<CR>
map <Leader>q :close<CR>
map <Leader>w :tabclose<CR>
nnoremap <Leader>/ :nohlsearch<CR>

" highlight the current line
nnoremap <Leader>L :call matchadd('Search', '\%'.line('.').'l')<CR>
" clear all the highlighted lines
nnoremap <Leader>C :call clearmatches()<CR>

" fzf.vim mappings
nnoremap <Leader>o :Rg<CR>
nnoremap <leader>O :Rg <C-R><C-W><CR>
nnoremap <Leader>t :Tags<CR>

" Moving around windows
map <C-k> <C-W>k
map <C-j> <C-W>j
map <C-l> <C-W>l
map <C-h> <C-W>h
" Resize current window to 90 wide.
map <Leader>a :90 wincmd \| <CR>
map <Leader>A :180 wincmd \| <CR>

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" ALE mappings
" Go to next/previous ALE warning or error.
nmap <silent> [a <Plug>(ale_previous)
nmap <silent> ]a <Plug>(ale_next)
" Toggle on/off ALE linting
nmap <Leader>e :ALEToggle<CR>

" Vimspector mappings
nnoremap <Leader>dd :call vimspector#Launch()<CR>
nnoremap <Leader>de :call vimspector#Reset()<CR>

nmap <Leader>dt <Plug>VimspectorToggleBreakpoint
nnoremap <Leader>dT :call vimspector#ClearBreakpoints()<CR>
nmap <Leader>dr <Plug>VimspectorRestart
nmap <Leader>dc <Plug>VimspectorContinue
nmap <Leader>dk <Plug>VimspectorStepOut
nmap <Leader>dj <Plug>VimspectorStepInto
nmap <Leader>dl <Plug>VimspectorStepOver

" Mapping of function keys
" Note that holding shifts gives F13 to F24
" holding control gives F25 to F36
" holding alt (or ctrl-shift) gives F37 to F48
nmap <F1> :Files<CR>
noremap <F2> :BufExplorer<CR>
" nmap <F2> :BufExplorer<CR>
nmap <F3> :Tagbar <CR>
nmap <F5> :Flog<CR>
" S-F5
nmap <F17> :Flog -path=%<CR>
nmap <F6> :Gtabedit :<CR>:set previewwindow <CR>
" S-F6
nmap <F18> :GitGutterFold<CR>
" C-F6
nmap <F30> :Gclog<CR>
" CS-F6
nmap <F42> :Gedit <CR> \| :ccl <CR>
nmap <F8> :Git commit<CR>
" S-F8
nmap <F20> :Git push origin HEAD<CR>
" CS-F8
nmap <F44> :Git rebase -i master<CR>
nmap <F9> :UndotreeToggle<CR>
