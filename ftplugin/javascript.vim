if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
                \ '`': {'closer': '`', 'not_in': ['String']},
                \ '/\*\*': {'closer': '\*/', 'not_in': ['String']}
                \ }, 'keep')
endif
