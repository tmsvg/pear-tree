if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = {
                \ '(': {'delimiter': ')'},
                \ '[': {'delimiter': ']'},
                \ '{': {'delimiter': '}'},
                \ "'": {'delimiter': "'", 'not_in': ['String']},
                \ '"': {'delimiter': '"', 'not_in': ['String']},
                \ 'r"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'R"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'u"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'U"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'f"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'F"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'b"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ 'B"': {'delimiter': '"', 'not_in': ['String', 'Comment']},
                \ "r'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "R'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "u'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "U'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "f'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "F'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "b'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ "B'": {'delimiter': "'", 'not_in': ['String', 'Comment']},
                \ }
endif