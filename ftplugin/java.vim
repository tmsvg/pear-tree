" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.7
" License: MIT
" Website: https://github.com/tmsvg/pear-tree

if exists('b:did_ftplugin') || exists('b:pear_tree_pairs')
    finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
            \ '/\*\*': {'closer': '\*/'}
            \ }, 'keep')

let &cpoptions = s:save_cpo
unlet s:save_cpo
