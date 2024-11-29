
" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists("b:undo_ftplugin") | let b:undo_ftplugin = '' | endif
let b:undo_ftplugin .= ' | unlet! b:pear_tree_pairs'

let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
            \ '\\begin{*}': {'closer': '\\end{*}', 'until': '[{}[:space:]]'},
            \ '$$': {'closer': '$$'},
            \ '$': {'closer': '$'}
            \ }, 'keep')

let &cpoptions = s:save_cpo
unlet s:save_cpo
