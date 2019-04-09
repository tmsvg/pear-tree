" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim


function! s:TrieNode(char) abort
    return {'char': a:char,
          \ 'children': {},
          \ 'parent': {},
          \ 'is_end_of_string': 0}
endfunction


function! pear_tree#trie#New(strings) abort
    let l:trie = {'root': s:TrieNode(''),
                \ 'wildcard_symbol': 'wc'}
    for l:str in a:strings
        call pear_tree#trie#Insert(l:trie, l:str)
    endfor
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
    let l:current.is_end_of_string = 1
    return a:trie
endfunction


function! s:GetStrings(node, string) abort
    if a:node.children == {}
        return [a:string]
    endif
    let l:strings = []
    for [l:ch, l:node] in items(a:node.children)
        call extend(l:strings, s:GetStrings(l:node, a:string . l:ch))
    endfor
    return l:strings
endfunction


function! pear_tree#trie#Strings(trie) abort
    return map(s:GetStrings(a:trie.root, ''), "pear_tree#string#Decode(v:val, '*', a:trie.wildcard_symbol)")
endfunction


function! pear_tree#trie#Prefix(trie, node) abort
    let l:string = []
    let l:current = a:node
    while l:current != a:trie.root
        let l:string = add(l:string, l:current.char)
        let l:current = l:current.parent
    endwhile
    let l:string = join(reverse(l:string), '')
    return pear_tree#string#Decode(l:string, '*', a:trie.wildcard_symbol)
endfunction


function! pear_tree#trie#GetChild(trie_node, char) abort
    return get(a:trie_node.children, a:char, {})
endfunction


function! pear_tree#trie#HasChild(trie_node, char) abort
    return has_key(a:trie_node.children, a:char)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
