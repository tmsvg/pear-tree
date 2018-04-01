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


function! s:BufferEnable()
    if exists('b:pear_tree_enabled') && b:pear_tree_enabled
        return
    endif
    if !exists('b:pear_tree_pairs')
        let b:pear_tree_pairs = g:pear_tree_pairs
    endif

    let l:trie = pear_tree#trie#New()
    call s:MapPairs(l:trie)

    if exists('s:mappings')
        for l:map in keys(s:mappings)
            execute 'imap <buffer> ' . l:map . ' ' . s:mappings[l:map]
        endfor
    else
        call s:MapDefaults()
    endif

    call pear_tree#insert_mode#Prepare(l:trie)

    let b:pear_tree_enabled = 1
endfunction


function! s:MapPairs(trie)
    for [l:opener, l:delimiter] in items(b:pear_tree_pairs)
        let l:delimiter = get(l:delimiter, 'delimiter')
        call a:trie.Insert(l:opener)

        let l:opener = l:opener[-1:]
        let l:escaped_opener = substitute(l:opener, "'", "''", 'g')

        execute 'inoremap <silent> <expr> <buffer> ' . l:opener . ' pear_tree#TerminateOpener(''' . l:escaped_opener . ''')'

        if strlen(l:delimiter) == 1 && !has_key(g:pear_tree_pairs, l:delimiter)
            let l:escaped_delimiter = substitute(l:delimiter, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> ' . l:delimiter . ' pear_tree#OnPressDelimiter(''' . l:escaped_delimiter . ''')'
        endif
    endfor
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


function! s:BufferDisable()
    if !exists('b:pear_tree_enabled') || !b:pear_tree_enabled
        return
    endif
    let s:mappings = {}
    " Unmap keys
    for l:map in map(split(execute('imap'), '\n'), 'split(v:val, ''\s\+'')[1]')
        if l:map =~# '^<Plug>(PearTree'
            continue
        endif
        let l:map_arg = maparg(l:map, 'i')
        if l:map_arg =~# '^pear_tree#'
            execute 'silent! iunmap <buffer> ' . l:map
        elseif l:map_arg =~# '^<Plug>(PearTree'
            let s:mappings[l:map] = l:map_arg
            execute 'silent! iunmap <buffer> ' . l:map
        endif
    endfor
    let b:pear_tree_enabled = 0
endfunction


inoremap <silent> <expr> <Plug>(PearTreeBackspace) pear_tree#Backspace()
inoremap <silent> <expr> <Plug>(PearTreeJump) pear_tree#JumpOut()
inoremap <silent> <expr> <Plug>(PearTreeJNR) pear_tree#JumpNReturn()
inoremap <silent> <expr> <Plug>(PearTreeExpand) pear_tree#PrepareExpansion()
inoremap <silent> <expr> <Plug>(PearTreeExpandOne) pear_tree#ExpandOne()
inoremap <silent> <expr> <Plug>(PearTreeFinishExpansion) pear_tree#Expand()

command -bar PearTreeEnable call s:BufferEnable()
command -bar PearTreeDisable call s:BufferDisable()

augroup pear_tree
    autocmd!
    autocmd BufRead,BufNewFile *
                \ if (index(g:pear_tree_ft_disabled, &filetype) == -1) |
                \       call <SID>BufferEnable() |
                \ endif
    autocmd CursorMovedI,InsertEnter *
                \ if exists('b:pear_tree_enabled') && b:pear_tree_enabled |
                \       call pear_tree#insert_mode#CursorMoved() |
                \ endif
    autocmd InsertCharPre *
                \ if exists('b:pear_tree_enabled') && b:pear_tree_enabled |
                \       call pear_tree#insert_mode#HandleKeypress() |
                \ endif
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
