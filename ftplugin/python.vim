if !exists('b:pear_tree_pairs')
    let b:pear_tree_pairs = extend(deepcopy(g:pear_tree_pairs), {
                \ '`': {'closer': '`', 'not_in': ['String']},
                \ 'r"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'R"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'u"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'U"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'f"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'F"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'b"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ 'B"': {'closer': '"', 'not_in': ['String', 'Comment']},
                \ "r'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "R'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "u'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "U'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "f'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "F'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "b'": {'closer': "'", 'not_in': ['String', 'Comment']},
                \ "B'": {'closer': "'", 'not_in': ['String', 'Comment']}
                \ }, 'keep')
endif
