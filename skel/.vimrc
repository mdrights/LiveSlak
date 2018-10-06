" My customizations
"set nu
set go=
colorscheme desert
set guifont=Courier_New
" set guifont=Go\ Mono\ for\ Powerline\ 11
syntax on
set nocompatible
set encoding=utf-8
set showcmd
"winpos 5 5
"set lines=40 columns=100
set termencoding=utf-8
set encoding=utf-8
set clipboard+=unnamed
set nobackup
set autoindent
set cindent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set ignorecase
set showmatch
set hlsearch
set incsearch
autocmd InsertLeave * se cul		"underlining when leaving edit mode.
autocmd InsertEnter * se nocul


" Punc auto-complete
:inoremap ( ()<ESC>i
:inoremap ) <c-r>=ClosePair(')')<CR>
:inoremap { {}<ESC>i
:inoremap } <c-r>=ClosePair('}')<CR>
:inoremap [ []<ESC>i
:inoremap ] <c-r>=ClosePair(']')<CR>
:inoremap " ""<ESC>i
:inoremap ' ''<ESC>i

" Statusline if no Powerline
 set statusline=%f\ -\ %y
 set statusline+=\ -\ 
 set statusline+=%l    " Current line
 set statusline+=/    " Separator
 set statusline+=%L   " Total lines

" PLUGINS
" Powerline
set laststatus=2
"set rtp+=/usr/local/repo/powerline/powerline/bindings/vim
"set rtp+=/home/user/src/powerline/powerline/bindings/vim

" Syntastic
""set statusline+=%#warningmsg#
""set statusline+=%{SyntasticStatuslineFlag()}
""set statusline+=%*
""
""let g:syntastic_always_populate_loc_list = 1
""let g:syntastic_auto_loc_list = 1
""let g:syntastic_check_on_open = 0
""let g:syntastic_check_on_wq = 0


" Vundle
""filetype off                  " required

" set the runtime path to include Vundle and initialize
""set rtp+=~/.vim/bundle/Vundle.vim
""call vundle#begin()
	" alternatively, pass a path where Vundle should install plugins
	"call vundle#begin('~/some/path/here')

	" let Vundle manage Vundle, required
	""Plugin 'VundleVim/Vundle.vim'

	" The following are examples of different formats supported.
	" Keep Plugin commands between vundle#begin/end.
	" plugin on GitHub repo
	"Plugin 'tpope/vim-fugitive'
	" plugin from http://vim-scripts.org/vim/scripts.html
	" Plugin 'L9'
	" Git plugin not hosted on GitHub
	"Plugin 'git://git.wincent.com/command-t.git'
	" git repos on your local machine (i.e. when working on your own plugin)
	"Plugin 'file:///home/gmarik/path/to/plugin'
""	Plugin 'file:///home/vagrant/.vim/bundle/syntastic'
""	Plugin 'file:///home/vagrant/.vim/bundle/YouCompleteMe'
	" The sparkup vim script is in a subdirectory of this repo called vim.
	" Pass the path to set the runtimepath properly.
	"Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
	" Install L9 and avoid a Naming conflict if you've already installed a
	" different version somewhere else.
	" Plugin 'ascenator/L9', {'name': 'newL9'}

	" All of your Plugins must be added before the following line
	""call vundle#end()            " required
	filetype plugin indent on    " required
	" To ignore plugin indent changes, instead use:
	"filetype plugin on
	"
	" Brief help
	" :PluginList       - lists configured plugins
	" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
	" :PluginSearch foo - searches for foo; append `!` to refresh local cache
	" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
	"
	" see :h vundle for more details or wiki for FAQ
	" Put your non-Plugin stuff after this line
