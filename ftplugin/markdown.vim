if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = {
                \ '(': {'delimiter': ')'},
                \ '[': {'delimiter': ']'},
                \ '{': {'delimiter': '}'},
                \ "'": {'delimiter': "'", 'not_in': ['String']},
                \ '"': {'delimiter': '"', 'not_in': ['String']},
                \ '`': {'delimiter': '`', 'not_in': ['String']},
                \ '<': {'delimiter': '>', 'not_in': ['String']}
                \ }
endif
