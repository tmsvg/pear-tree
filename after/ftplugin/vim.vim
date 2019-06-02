" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree

if !exists('g:pear_tree_pairs') || get(b:, 'pear_tree_did_vim_ftplugin', 0)
    finish
endif
let b:pear_tree_did_vim_ftplugin = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('b:undo_ftplugin')
    let b:undo_ftplugin = ''
else
    let b:undo_ftplugin .= ' | '
endif
let b:undo_ftplugin .= 'unlet! b:pear_tree_did_vim_ftplugin b:pear_tree_pairs'

let b:pear_tree_pairs = deepcopy(g:pear_tree_pairs)
if has_key(b:pear_tree_pairs, '"')
    let b:pear_tree_pairs['"']['not_at'] = get(b:pear_tree_pairs['"'], 'not_at', []) + ['\w', '^\s*', '\t', '\s\{2}']
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
