" Required:
set runtimepath+=~/.cache/dein/repos/github.com/Shougo/dein.vim

" Required:
if dein#load_state('/home/r3coms/.cache/dein')
    call dein#begin('/home/r3coms/.cache/dein')

    " Let dein manage dein
    " Required:
    call dein#add('/home/r3coms/.cache/dein/repos/github.com/Shougo/dein.vim')

    " Add or remove your plugins here:
    call dein#add('sheerun/vim-polyglot')
    call dein#add('Shougo/vimshell')
    call dein#add('Shougo/neosnippet.vim')
    call dein#add('Shougo/neco-syntax')
    call dein#add('Shougo/neoinclude.vim')
    call dein#add('Shougo/neosnippet-snippets')
    call dein#add('Shougo/neco-vim')
    " call dein#add('ncm2/ncm2')
    " call dein#add('ncm2/ncm2-syntax')
    " call dein#add('ncm2/ncm2-path')
    " call dein#add('ncm2/ncm2-neoinclude')
    " call dein#add('ncm2/ncm2-neosnippet')
    " call dein#add('ncm2/ncm2-vim')
    " call dein#add('ncm2/ncm2-markdown-subscope')
    call dein#add('roxma/nvim-yarp')
    call dein#add('vim-airline/vim-airline')
    call dein#add('vim-airline/vim-airline-themes')
    call dein#add('scrooloose/nerdtree')
    call dein#add('scrooloose/nerdcommenter')
    call dein#add('crusoexia/vim-monokai')
    call dein#add('Konfekt/FastFold')
    call dein#add('cloudhead/neovim-fuzzy')
    call dein#add('neomutt/neomutt.vim')
    call dein#add('christoomey/vim-tmux-navigator')
    call dein#add('plasticboy/vim-markdown')
    call dein#add('jamessan/vim-gnupg')
    call dein#add('daeyun/vim-matlab')
    "call dein#add('autozimu/LanguageClient-neovim', {
    "            \ 'rev': 'next',
    "            \ 'build': 'bash install.sh',
    "            \ })
    call dein#add('neoclide/coc.nvim', {'merge':0, 'rev': 'release'})
    call dein#add('LucHermitte/lh-vim-lib')
    call dein#add('LucHermitte/lh-style')
    call dein#add('LucHermitte/lh-tags')
    call dein#add('LucHermitte/lh-dev')
    call dein#add('LucHermitte/lh-brackets')
    call dein#add('LucHermitte/searchInRuntime')
    call dein#add('LucHermitte/mu-template')
    call dein#add('tomtom/stakeholders_vim')
    call dein#add('LucHermitte/alternate-lite')
    call dein#add('LucHermitte/lh-cpp')

    call dein#add('jackguo380/vim-lsp-cxx-highlight')
    " Required:
    call dein#end()
    call dein#save_state()
endif

" Required:
filetype plugin indent on
syntax enable

" If you want to install not installed plugins on startup.
if dein#check_install()
    call dein#install()
endif

"End dein Scripts-------------------------
