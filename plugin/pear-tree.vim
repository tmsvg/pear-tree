scriptencoding utf-8

if exists('g:loaded_pear_tree') || v:version < 704 || &compatible
    finish
endif
let g:loaded_pear_tree = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:pear_tree_ft_disabled')
    let g:pear_tree_ft_disabled = []
endif

if !exists('g:pear_tree_pairs')
    let g:pear_tree_pairs = {
                \ '(': {'delimiter': ')'},
                \ '[': {'delimiter': ']'},
                \ '{': {'delimiter': '}'},
                \ "'": {'delimiter': "'", 'not_in': ['String']},
                \ '"': {'delimiter': '"', 'not_in': ['String']}
                \ }
endif


function! s:Init()
    if exists('b:pear_tree_did_init')
        return
    endif
    if !exists('b:pear_tree_pairs')
        let b:pear_tree_pairs = g:pear_tree_pairs
    endif

    let l:trie = pear_tree#trie#New()

    for [l:opener, l:delimiter] in items(b:pear_tree_pairs)
        let l:delimiter = get(l:delimiter, 'delimiter')
        call l:trie.Insert(l:opener)

        let l:opener = l:opener[strlen(l:opener) - 1]
        let l:escaped_opener = substitute(l:opener, "'", "''", 'g')

        execute 'inoremap <silent> <expr> <buffer> ' . l:opener . " pear_tree#TerminateOpener('". l:escaped_opener . "')"

        if strlen(l:delimiter) == 1 && !has_key(g:pear_tree_pairs, l:delimiter)
            let l:escaped_delimiter = substitute(l:delimiter, "'", "''", 'g')
            execute 'inoremap <silent> <expr> <buffer> ' . l:delimiter . " pear_tree#OnPressDelimiter('". l:escaped_delimiter . "')"
        endif
    endfor

    call pear_tree#insert_mode#Prepare(l:trie)
    let b:pear_tree_did_init = 1
endfunction


inoremap <silent> <expr> <Plug>PearTreeBackspace pear_tree#Backspace()
inoremap <silent> <expr> <Plug>PearTreeJump pear_tree#JumpOut()
inoremap <silent> <expr> <Plug>PearTreeJNR pear_tree#JumpNReturn()
inoremap <silent> <expr> <Plug>PearTreeExpand pear_tree#PrepareExpansion()
inoremap <silent> <expr> <Plug>PearTreeOnceExpand pear_tree#ExpandOne()
inoremap <silent> <expr> <Plug>PearTreeFinishExpansion pear_tree#Expand()

if !hasmapto('<Plug>PearTreeBackspace', 'i')
    imap <BS> <Plug>PearTreeBackspace
endif

if !hasmapto('<Plug>PearTreeExpand', 'i')
    imap <CR> <Plug>PearTreeExpand
endif

if !hasmapto('<Plug>PearTreeFinishExpansion', 'i')
    imap <ESC> <Plug>PearTreeFinishExpansion
endif

if !hasmapto('<Plug>PearTreeJump', 'i')
    imap <C-l> <Plug>PearTreeJump
endif

augroup pear-tree
    autocmd!
    autocmd BufEnter * call <SID>Init()
    autocmd CursorMovedI,InsertEnter * call pear_tree#insert_mode#CursorMoved()
    autocmd InsertCharPre * call pear_tree#insert_mode#HandleKeypress()
augroup END


let &cpoptions = s:save_cpo
unlet s:save_cpo
