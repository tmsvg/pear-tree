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

if !exists('g:pear_tree_smart_backspace')
    let g:pear_tree_smart_backspace = 0
endif


function! s:BufferEnable()
    if exists('b:pear_tree_enabled') && b:pear_tree_enabled
        return
    endif
    call s:MapPairs()
    if exists('s:saved_mappings')
        for l:map in keys(s:saved_mappings)
            execute 'imap <buffer> ' . l:map . ' ' . s:saved_mappings[l:map]
        endfor
    else
        call s:MapDefaults()
    endif
    call pear_tree#insert_mode#Prepare()
    let b:pear_tree_enabled = 1
endfunction


function! s:BufferDisable()
    if !(exists('b:pear_tree_enabled') && b:pear_tree_enabled)
        return
    endif
    call s:UnmapPairs()

    let s:saved_mappings = {}
    for l:map in map(split(execute('imap'), '\n'), 'split(v:val, ''\s\+'')[1]')
        let l:map_arg = maparg(l:map, 'i')
        if l:map_arg =~# '^<Plug>(PearTree'
            let s:saved_mappings[l:map] = l:map_arg
            execute 'silent! iunmap <buffer> ' . l:map
        endif
    endfor
    let b:pear_tree_enabled = 0
endfunction


function! s:MapPairs()
    for l:opener in keys(pear_tree#Pairs())
        let l:delim = pear_tree#GetRule(l:opener, 'delimiter')
        let l:opener = l:opener[-1:]

        let l:escaped_opener = substitute(l:opener, "'", "''", 'g')
        execute 'inoremap <silent> <expr> <buffer> '
                    \ . l:opener
                    \ . ' pear_tree#TerminateOpener('''
                    \ . l:escaped_opener . ''')'

        if strlen(l:delim) == 1 && !has_key(pear_tree#Pairs(), l:delim)
            let l:escaped_delim = substitute(l:delim, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> '
                        \ . l:delim
                        \ . ' pear_tree#OnPressDelimiter('''
                        \ . l:escaped_delim . ''')'
        endif
    endfor
endfunction


function! s:UnmapPairs()
    for l:opener in keys(pear_tree#Pairs())
        let l:delim = pear_tree#GetRule(l:opener, 'delimiter')
        let l:opener = l:opener[-1:]

        if maparg(l:opener, 'i') =~# '^pear_tree#'
            execute 'silent! iunmap <buffer> ' . l:opener
        endif
        if maparg(l:delim, 'i') =~# '^pear_tree#'
            execute 'silent! iunmap <buffer> ' . l:opener
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
