if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
                \ '`': {'closer': '`'}
                \ }, 'keep')
endif
