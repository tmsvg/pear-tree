" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim


function! pear_tree#cursor#Position() abort
    return [line('.'), col('.')]
endfunction


function! pear_tree#cursor#PrevChar() abort
    return matchstr(getline('.'), '\%' . (col('.') - 1) . 'c.')
endfunction


function! pear_tree#cursor#NextChar() abort
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction


function! pear_tree#cursor#TextBefore() abort
    return getline('.')[:(col('.') - 2)]
endfunction


function! pear_tree#cursor#TextAfter() abort
    return getline('.')[(col('.') - 1):]
endfunction


function! pear_tree#cursor#OnEmptyLine() abort
    return (col('$') == 1)
endfunction


function! pear_tree#cursor#AtEndOfLine() abort
    return (col('.') == col('$'))
endfunction


function! pear_tree#cursor#SyntaxRegion() abort
    return synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
