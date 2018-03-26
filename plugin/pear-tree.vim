if exists('g:loaded_pear_tree') || v:version < 704 || &compatible
    finish
endif
let g:loaded_pear_tree = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:pear_tree_pairs')
    let g:pear_tree_pairs = {
                \ '(': {'delimiter': ')'},
                \ '[': {'delimiter': ']'},
                \ '{': {'delimiter': '}'},
                \ "'": {'delimiter': "'", 'not_in': ['String']},
                \ '"': {'delimiter': '"', 'not_in': ['String']}
                \ }
endif

if !exists('g:pear_tree_ft_disabled')
    let g:pear_tree_ft_disabled = []
endif


function! s:BufferInit()
    if !exists('b:pear_tree_pairs')
        let b:pear_tree_pairs = g:pear_tree_pairs
    endif

    let l:trie = pear_tree#trie#New()

    call s:MapPairs(l:trie)
    call s:MapDefaults()
    call s:PrepareAutoCommands()
    call pear_tree#insert_mode#Prepare(l:trie)
endfunction


function! s:MapPairs(trie)
    let s:mappings = []
    for [l:opener, l:delimiter] in items(b:pear_tree_pairs)
        let l:delimiter = get(l:delimiter, 'delimiter')
        call a:trie.Insert(l:opener)

        let l:opener = l:opener[-1:]
        let l:escaped_opener = substitute(l:opener, "'", "''", 'g')

        execute 'inoremap <silent> <expr> <buffer> ' . l:opener . ' pear_tree#TerminateOpener(''' . l:escaped_opener . ''')'

        if strlen(l:delimiter) == 1 && !has_key(g:pear_tree_pairs, l:delimiter)
            let l:escaped_delimiter = substitute(l:delimiter, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> ' . l:delimiter . ' pear_tree#OnPressDelimiter(''' . l:escaped_delimiter . ''')'
            call add(s:mappings, l:delimiter)
        endif
        call add(s:mappings, l:opener)
    endfor
    let b:pear_tree_enabled = 1
endfunction


function! s:BufferDisable()
    for l:mapping in s:mappings
        if maparg(l:mapping, 'i') =~# '^pear_tree#'
            execute 'silent! iunmap <buffer> ' . l:mapping
        endif
    endfor

    unlet s:mappings

    augroup pear_tree
        autocmd!
    augroup END
    let b:pear_tree_enabled = 0
endfunction


function! s:PrepareAutoCommands()
    augroup pear_tree
        autocmd!
        autocmd CursorMovedI,InsertEnter * call pear_tree#insert_mode#CursorMoved()
        autocmd InsertCharPre * call pear_tree#insert_mode#HandleKeypress()
    augroup END
endfunction


function! s:MapDefaults()
    if !hasmapto('<Plug>(PearTreeBackspace)', 'i')
        imap <buffer> <BS> <Plug>(PearTreeBackspace)
    endif

    if !hasmapto('<Plug>(PearTreeExpand)', 'i')
        imap <buffer> <CR> <Plug>(PearTreeExpand)
    endif

    if !hasmapto('<Plug>(PearTreeFinishExpansion)', 'i')
        imap <buffer> <ESC> <Plug>(PearTreeFinishExpansion)
    endif

    if !hasmapto('<Plug>(PearTreeJump)', 'i')
        imap <buffer> <C-l> <Plug>(PearTreeJump)
    endif
endfunction


inoremap <silent> <expr> <Plug>(PearTreeBackspace) pear_tree#Backspace()
inoremap <silent> <expr> <Plug>(PearTreeJump) pear_tree#JumpOut()
inoremap <silent> <expr> <Plug>(PearTreeJNR) pear_tree#JumpNReturn()
inoremap <silent> <expr> <Plug>(PearTreeExpand) pear_tree#PrepareExpansion()
inoremap <silent> <expr> <Plug>(PearTreeExpandOne) pear_tree#ExpandOne()
inoremap <silent> <expr> <Plug>(PearTreeFinishExpansion) pear_tree#Expand()

command -bar PearTreeEnable call s:BufferInit()
command -bar PearTreeDisable call s:BufferDisable()

augroup pear_tree_init
    autocmd!
    autocmd FileType * if index(g:pear_tree_ft_disabled, &filetype) == -1 | call <SID>BufferInit() | endif
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
