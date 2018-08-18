if !exists('b:pear_tree_pairs')
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
                \ "B'": {'closer': "'"}
                \ }, 'keep')
endif
