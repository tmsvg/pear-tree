let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
                \ '`': {'closer': '`'}
                \ }, 'keep')
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
