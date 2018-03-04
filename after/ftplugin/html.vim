if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = {
                \ '(': {'delimiter': ')'},
                \ '[': {'delimiter': ']'},
                \ '{': {'delimiter': '}'},
                \ "'": {'delimiter': "'", 'not_in': ['String']},
                \ '"': {'delimiter': '"', 'not_in': ['String']},
                \ '<*>': {'delimiter': '</*>',
                \         'not_in': ['String', 'Comment'],
                \         'not_if': ['br', 'hr', 'img', 'input', 'link', 'meta',
                \                    'area', 'base', 'col', 'command', 'embed',
                \                    'keygen', 'param', 'source', 'track', 'wbr'],
                \        },
                \ '<!--': {'delimiter': '-->'},
                \ }
endif
