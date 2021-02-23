" For Windows
set rtp^=$HOME/.vim

" Powerline
"set rtp+=$HOME/.local/lib/python2.7/site-packages/powerline/bindings/vim

" menus
set langmenu=en_US
let $LANG = 'en_US'
source $VIMRUNTIME/delmenu.vim
source $VIMRUNTIME/menu.vim
set guioptions-=T   " tool
set guioptions-=m   " menu 
set guioptions-=r   " scroll

" Airline
let g:airline_powerline_fonts=1 
let g:airline_theme='powerlineish'

" Appearance
colorscheme Tomorrow-Night-Bright
set guifont=Source\ Code\ Pro
"set guifont=Source\ Code\ Pro\ for\ Powerline
"set cursorline 
set laststatus=2
set noshowmode
set number
nmap <C-N><C-N> :set invnumber<CR>
set numberwidth=5
set cpoptions+=n
"highlight LineNr term=bold cterm=NONE ctermfg=DarkGrey ctermbg=NONE gui=NONE guifg=DarkGrey guibg=NONE
"nmap <C-N><C-N><C-N> :set relativenumber
"set fillchars+=vert:\|
hi! VertSplit guifg=bg guibg=bg gui=NONE
"hi! VertSplit ctermfg=bg ctermbg=bg term=NONE
hi! NonText guifg=bg
"hi! NonText ctermfg=bg
" Set background else termux will use orange
hi Normal ctermbg=black

" Nerdtree
let g:NERDTreeWinPos = "right"
"nmap <C-N><C-T> :NERDTree
nnoremap <silent> <expr> <F6> g:NERDTree.IsOpen() ? "\:NERDTreeClose<CR>" : bufexists(expand('%')) ? "\:NERDTreeFind<CR>" : "\:NERDTree<CR>"

