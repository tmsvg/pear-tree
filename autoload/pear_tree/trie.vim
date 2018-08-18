function! s:TrieNode(char) abort
    return {'char': a:char,
          \ 'children': {},
          \ 'parent': {},
          \ 'is_end_of_string': 0}
endfunction


function! pear_tree#trie#New(...) abort
    let l:trie = {'root': s:TrieNode(''),
                \ 'leaves': [],
                \ 'wildcard_symbol': 'wc'}
    if a:0 == 0
        return l:trie
    elseif type(a:1) == type([])
        for l:str in a:1
            call pear_tree#trie#Insert(l:trie, l:str)
        endfor
    elseif type(a:1) == type('')
        call pear_tree#trie#Insert(l:trie, l:str)
    endif
    return l:trie
endfunction


function! pear_tree#trie#Insert(trie, str) abort
    let l:current = a:trie.root
    for l:ch in pear_tree#string#Tokenize(a:str, '*', a:trie.wildcard_symbol)
        if !has_key(l:current.children, l:ch)
            let l:node = s:TrieNode(l:ch)
            let l:current.children[l:ch] = l:node
            let l:node.parent = l:current
        else
            let l:node = get(l:current.children, l:ch)
        endif
        let l:current = l:node
    endfor
    call add(a:trie.leaves, l:current)
    let l:current.is_end_of_string = 1
    return a:trie
endfunction


function! pear_tree#trie#Strings(trie) abort
    return map(copy(a:trie.leaves), 'pear_tree#trie#Prefix(a:trie, v:val)')
endfunction


function! pear_tree#trie#Prefix(trie, node) abort
    let l:string = []
    let l:current = a:node
    while l:current != a:trie.root
        let l:string = add(l:string, l:current.char)
        let l:current = l:current.parent
    endwhile
    return pear_tree#string#Decode(join(reverse(l:string), ''), '*', a:trie.wildcard_symbol)
endfunction


function! pear_tree#trie#GetChild(trie_node, char) abort
    return get(a:trie_node.children, a:char, {})
endfunction


function! pear_tree#trie#HasChild(trie_node, char) abort
    return has_key(a:trie_node.children, a:char)
endfunction
