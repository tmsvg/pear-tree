" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


if exists('g:loaded_pear_tree') || v:version < 704
    finish
endif
let g:loaded_pear_tree = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:pear_tree_pairs')
    let g:pear_tree_pairs = {
                \ '(': {'closer': ')'},
                \ '[': {'closer': ']'},
                \ '{': {'closer': '}'},
                \ "'": {'closer': "'"},
                \ '"': {'closer': '"'}
                \ }
endif

if !exists('g:pear_tree_ft_disabled')
    let g:pear_tree_ft_disabled = []
endif

if !exists('g:pear_tree_map_special_keys')
    let g:pear_tree_map_special_keys = 1
endif

if !exists('g:pear_tree_repeatable_expand')
    let g:pear_tree_repeatable_expand = 1
endif

if !exists('g:pear_tree_smart_backspace')
    let g:pear_tree_smart_backspace = 0
endif

if !exists('g:pear_tree_smart_openers')
    let g:pear_tree_smart_openers = 0
endif

if !exists('g:pear_tree_smart_closers')
    let g:pear_tree_smart_closers = 0
endif

if !exists('g:pear_tree_timeout')
    let g:pear_tree_timeout = has('reltime') ? 60 : 0
endif


function! s:BufferEnable()
    if get(b:, 'pear_tree_enabled', 0)
        return
    endif
    call s:CreatePlugMappings()
    if get(b:, 'pear_tree_timeout', get(g:, 'pear_tree_timeout', 0)) > 0 && !has('reltime')
        echohl WarningMsg
        echom 'Pear Tree: pear_tree_timeout requires Vim compiled with reltime support.'
        echohl None
        let b:pear_tree_timeout = 0
        let g:pear_tree_timeout = 0
    endif
    if !exists('b:pear_tree_enabled')
        call s:MapDefaults()
    endif
    let b:pear_tree_enabled = 1
endfunction


function! s:BufferDisable()
    if !get(b:, 'pear_tree_enabled', 0)
        return
    endif
    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for [l:opener, l:closer] in map(items(l:pairs), '[v:val[0][-1:], v:val[1].closer]')
        if l:opener ==# '|'
            let l:opener = '<Bar>'
        endif
        let l:opener_plug = '<Plug>(PearTreeOpener_' . l:opener . ')'
        let l:closer_plug = '<Plug>(PearTreeCloser_' . l:closer . ')'

        execute 'inoremap <silent> <buffer> ' . l:opener_plug . ' ' . l:opener
        if mapcheck(l:closer_plug, 'i') !=# ''
            execute 'inoremap <silent> <buffer> ' . l:closer_plug . ' ' . l:closer
        endif
    endfor
    inoremap <silent> <buffer> <Plug>(PearTreeBackspace) <BS>
    inoremap <silent> <buffer> <Plug>(PearTreeExpand) <CR>
    inoremap <silent> <buffer> <Plug>(PearTreeFinishExpansion) <Esc>
    inoremap <silent> <buffer> <Plug>(PearTreeExpandOne) <NOP>
    inoremap <silent> <buffer> <Plug>(PearTreeJump) <NOP>
    inoremap <silent> <buffer> <Plug>(PearTreeJNR) <NOP>
    let b:pear_tree_enabled = 0
endfunction


function! s:BufferUnload()
    call s:BufferDisable()
    call pear_tree#insert_mode#Unload()
    unlet! b:pear_tree_enabled
endfunction


function! s:CreatePlugMappings()
    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for [l:opener, l:closer] in map(items(l:pairs), '[v:val[0][-1:], v:val[1].closer]')
        if l:opener ==# "'"
            let l:escaped_opener = "''"
        elseif l:opener ==# '|'
            let l:opener = '<Bar>'
            let l:escaped_opener = '<Bar>'
        else
            let l:escaped_opener = l:opener
        endif
        execute 'inoremap <silent> <expr> <buffer> '
                    \ . '<Plug>(PearTreeOpener_' . l:opener . ') '
                    \ . 'pear_tree#insert_mode#TerminateOpener('''
                    \ . l:escaped_opener . ''')'

        if strlen(l:closer) == 1 && !has_key(l:pairs, l:closer)
            let l:escaped_closer = substitute(l:closer, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> '
                        \ . '<Plug>(PearTreeCloser_' . l:closer . ') '
                        \ . 'pear_tree#insert_mode#HandleCloser('''
                        \ . l:escaped_closer . ''')'
        endif
    endfor
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeBackspace) pear_tree#insert_mode#Backspace()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeExpand) pear_tree#insert_mode#PrepareExpansion()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeFinishExpansion) pear_tree#insert_mode#Expand()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeExpandOne) pear_tree#insert_mode#ExpandOne()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeJump) pear_tree#insert_mode#JumpOut()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeJNR) pear_tree#insert_mode#JumpNReturn()
    inoremap <silent> <expr> <buffer> <Plug>(PearTreeSpace) pear_tree#insert_mode#Space()
endfunction


function! s:MapDefaults()
    let l:restore_keymap = ''
    if has('keymap')
        let l:restore_keymap .= 'set keymap=' . &keymap
        let l:restore_keymap .= ' | set iminsert=' . &iminsert
        let l:restore_keymap .= ' | set imsearch=' . &imsearch
        set keymap=
    endif

    let l:pairs = get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
    for l:closer in map(values(l:pairs), 'v:val.closer')
        let l:closer_plug = '<Plug>(PearTreeCloser_' . l:closer . ')'
        if mapcheck(l:closer_plug, 'i') !=# '' && !hasmapto(l:closer_plug, 'i')
            execute 'imap <buffer> ' . l:closer . ' ' l:closer_plug
        endif
    endfor
    for l:opener in map(keys(l:pairs), 'v:val[-1:]')
        if l:opener ==# '|'
            let l:opener = '<Bar>'
        endif
        let l:opener_plug = '<Plug>(PearTreeOpener_' . l:opener . ')'
        if !hasmapto(l:opener_plug, 'i')
            execute 'imap <buffer> ' . l:opener . ' ' l:opener_plug
        endif
    endfor

    execute l:restore_keymap

    " Stop here if special keys shouldn't be mapped.
    if !get(b:, 'pear_tree_map_special_keys', get(g:, 'pear_tree_map_special_keys', 1))
                \ || stridx(&cpoptions, '<') > -1
        return
    endif
    if !hasmapto('<Plug>(PearTreeBackspace)', 'i')
        imap <buffer> <BS> <Plug>(PearTreeBackspace)
    endif
    if !hasmapto('<Plug>(PearTreeExpand)', 'i')
        imap <buffer> <CR> <Plug>(PearTreeExpand)
    endif
    if !hasmapto('<Plug>(PearTreeFinishExpansion)', 'i')
        if !has('nvim') && !has('gui_running')
            " Prevent <Esc> mapping from breaking cursor keys in insert mode
            imap <buffer> <Esc><Esc> <Plug>(PearTreeFinishExpansion)
            imap <buffer> <nowait> <Esc> <Plug>(PearTreeFinishExpansion)
        else
            imap <buffer> <Esc> <Plug>(PearTreeFinishExpansion)
        endif
    endif
endfunction


command -bar PearTreeEnable call s:BufferEnable()
command -bar PearTreeDisable call s:BufferDisable()

augroup pear_tree
    autocmd!
    autocmd FileType *
                \ if exists('b:pear_tree_enabled') |
                \     call <SID>BufferUnload() |
                \ endif |
                \ if index(g:pear_tree_ft_disabled, &filetype) > -1 |
                \     call <SID>BufferDisable() |
                \ endif
    autocmd InsertEnter *
                \ if !exists('b:pear_tree_enabled') && index(g:pear_tree_ft_disabled, &filetype) == -1 |
                \     call <SID>BufferEnable() |
                \ endif |
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#OnInsertEnter() |
                \     call pear_tree#insert_mode#OnCursorMovedI() |
                \ endif
    autocmd CursorMovedI *
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#OnCursorMovedI() |
                \ endif
    autocmd InsertCharPre *
                \ if get(b:, 'pear_tree_enabled', 0) |
                \     call pear_tree#insert_mode#OnInsertCharPre() |
                \ endif
augroup END

let &cpoptions = s:save_cpo
unlet s:save_cpo
