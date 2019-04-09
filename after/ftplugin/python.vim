" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.7
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
            \ 'r"': {'closer': '"'},
            \ 'R"': {'closer': '"'},
            \ 'u"': {'closer': '"'},
            \ 'U"': {'closer': '"'},
            \ 'f"': {'closer': '"'},
            \ 'F"': {'closer': '"'},
            \ 'b"': {'closer': '"'},
            \ 'B"': {'closer': '"'},
            \ "r'": {'closer': "'"},
            \ "R'": {'closer': "'"},
            \ "u'": {'closer': "'"},
            \ "U'": {'closer': "'"},
            \ "f'": {'closer': "'"},
            \ "F'": {'closer': "'"},
            \ "b'": {'closer': "'"},
            \ "B'": {'closer': "'"},
            \ '"""': {'closer': '"""'},
            \ "'''": {'closer': "'''"},
            \ }, 'keep')

let &cpoptions = s:save_cpo
unlet s:save_cpo
