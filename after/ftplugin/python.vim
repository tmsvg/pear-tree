" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree

let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('b:undo_ftplugin')
    let b:undo_ftplugin .= ' | unlet! b:pear_tree_pairs'
else
    let b:undo_ftplugin = 'unlet! b:pear_tree_pairs'
endif

let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
            \ '`': {'closer': '`'},
            \ '"""': {'closer': '"""'},
            \ "'''": {'closer': "'''"},
            \ }, 'keep')

let s:patterns = ['[^bBfFrRuU\W]',
                \ '\w\{3,}',
                \ '\w[bBuU]',
                \ '[^rR\W][fF]',
                \ '[^fF\W][rR]']
if has_key(b:pear_tree_pairs, '"')
    let b:pear_tree_pairs['"']['not_at'] = get(b:pear_tree_pairs['"'], 'not_at', []) + s:patterns
endif
if has_key(b:pear_tree_pairs, '''')
    let b:pear_tree_pairs['''']['not_at'] = get(b:pear_tree_pairs[''''], 'not_at', []) + s:patterns
endif

unlet s:patterns

let &cpoptions = s:save_cpo
unlet s:save_cpo
