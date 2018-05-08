function! pear_tree#trie#New() abort
    let l:obj = {'root': pear_tree#trie#Node('')}

    function! l:obj.Insert(str) abort
        let l:current = l:self.root
        for l:ch in split(a:str, '\zs')
            if !has_key(l:current.children, l:ch)
                let l:node = pear_tree#trie#Node(l:ch)
                let l:current.children[l:ch] = l:node
                let l:node.parent = l:current
            else
                let l:node = get(l:current.children, l:ch)
            endif
            let l:current = l:node
        endfor
        let l:current.is_end_of_string = 1
    endfunction

    function! l:obj.GetStrings(node, string, strings) abort
        let l:strings = a:strings
        let l:string = a:string
        if a:node.is_end_of_string
            call add(l:strings, l:string)
        endif
        for l:ch in keys(a:node.children)
            let l:string = l:string . l:ch
            call l:self.GetStrings(a:node.children[l:ch], l:string, l:strings)
            let l:string = ''
        endfor
        return l:strings
    endfunction

    return l:obj
endfunction


function! pear_tree#trie#Node(char) abort
    let l:obj = {'char': a:char,
             \ 'children': {},
             \ 'parent': {},
             \ 'is_end_of_string': 0}

    function! l:obj.GetChild(char) abort
        return get(l:self.children, a:char, {})
    endfunction

    function! l:obj.GetChildren() abort
        return l:self.children
    endfunction

    return l:obj
endfunction


function! pear_tree#trie#Traverser(trie) abort
    let l:obj = {'trie': a:trie,
             \ 'root': a:trie.root,
             \ 'current': a:trie.root,
             \ 'string': '',
             \ 'wildcard_string': ''}

    function! l:obj.StepToChild(char) abort
        let l:node = l:self.current.GetChild(a:char)
        let l:wildcard_node = l:self.current.GetChild('*')
        " We can step to the node with a:char
        if l:node != {}
            let l:self.current = l:node
            let l:self.string = l:self.string . a:char
            return 1
        " Try stepping to wildcard node
        elseif l:wildcard_node != {}
            let l:self.current = l:wildcard_node
            let l:self.string = l:self.string . '*'
            let l:self.wildcard_string = l:self.wildcard_string . a:char
            return 1
        elseif l:self.AtWildcard()
            let l:self.wildcard_string = l:self.wildcard_string . a:char
            return 1
        " Reached dead-end; go back
        else
            let l:node = l:self.Backtrack('*')
            if l:node != {}
                let l:self.current = l:node
                let l:new_string = l:self.GetStringAtNode()
                let l:self.wildcard_string = l:self.string[(strlen(l:new_string) - 1):]
                let l:self.string = l:new_string
                return l:self.StepToChild(a:char)
            else
                return 0
            endif
        endif
        return 0
    endfunction

    " Attempt to step to {char} in the trie. If this fails, or the traverser is
    " already at the end of the trie, reset the traverser.
    function! l:obj.StepOrReset(char) abort
        if !l:self.StepToChild(a:char) || (l:self.AtEndOfString() && !l:self.AtWildcard())
            call l:self.Reset()
        endif
    endfunction

    " Traverse the substring of {text} that begins at {start} and ends at {end}
    function! l:obj.Traverse(text, start, end) abort
        let l:idx_list = [a:end]
        for l:str in l:self.trie.GetStrings(l:self.root, '', [])
            if strlen(l:str) == 1
                continue
            endif
            " Find the index of the first opening character of l:str that
            " follows the most recent closing character of l:str.
            let l:idx = stridx(a:text, l:str[0], strridx(a:text, l:str[strlen(l:str) - 1], a:end - 1))
            if l:idx != -1
                call add(l:idx_list, l:idx)
            endif
        endfor
        let l:i = min(l:idx_list)
        while l:i < a:end
            if l:self.HasChild(l:self.current, '*')
                call l:self.StepOrReset(a:text[(l:i)])
            endif
            if l:self.AtRoot()
                " Ignore single-character strings that are in the trie since
                " stepping to one would only immediately reset the traverser.
                let l:indices = pear_tree#util#FindAll(a:text, filter(keys(l:self.root.children), 'l:self.root.GetChild(v:val).children != {}'), l:i)
            else
                let l:indices = pear_tree#util#FindAll(a:text, keys(l:self.current.children), l:i)
            endif
            call add(l:indices, a:end)
            if l:self.AtWildcard()
                let l:end_of_wc = min(l:indices) - 1
                let l:self.wildcard_string = l:self.wildcard_string . a:text[(l:i + 1):(l:end_of_wc)]
                let l:i = l:end_of_wc + 1
            elseif l:self.AtRoot()
                let l:i = min(l:indices)
            elseif l:indices == [] || min(l:indices) > l:i
                call l:self.Reset()
                continue
            endif
            call l:self.StepOrReset(a:text[(l:i)])
            let l:i = l:i + 1
        endwhile
    endfunction

    " Traverse the substring of {text} that begins at {start} and ends at {end}
    " until a character is reached that requires the traverser to reset.
    " Return the index of {text} at which the traverser reached a leaf, or -1
    " if the traverser did not reach a leaf.
    function! l:obj.WeakTraverse(text, start, end) abort
        let l:i = a:start
        while l:i < a:end
            if l:self.HasChild(l:self.GetCurrent(), '*')
                call l:self.StepToChild(a:text[(l:i)])
            endif
            if l:self.AtWildcard()
                let l:indices = [a:end] + pear_tree#util#FindAll(a:text, keys(l:self.current.children), l:i)
                let l:end_of_wc = min(l:indices) - 1
                let l:self.wildcard_string = l:self.wildcard_string . a:text[(l:i + 1):(l:end_of_wc)]
                let l:i = l:end_of_wc + 1
            endif
            if l:self.StepToChild(a:text[(l:i)])
                if l:self.AtEndOfString()
                    return l:i
                endif
            else
                call l:self.Reset()
                return -1
            endif
            let l:i = l:i + 1
        endwhile
    endfunction

    function! l:obj.StepToParent() abort
        if l:self.AtWildcard() && l:self.wildcard_string !=# ''
            let l:self.wildcard_string = l:self.wildcard_string[:-2]
        elseif l:self.current.parent != {}
            let l:self.current = l:self.current.parent
            let l:self.string = l:self.string[:-2]
        endif
    endfunction

    function! l:obj.Backtrack(char) abort
        let l:node = l:self.current
        while !has_key(l:node.children, a:char)
            let l:node = l:node.parent
            if l:node == {}
                return {}
            endif
        endwhile
        return get(l:node.children, a:char)
    endfunction

    function! l:obj.GetStringAtNode() abort
        let l:node = l:self.current
        let l:str = []
        while l:node != l:self.root
            let l:str = add(l:str, l:node.char)
            let l:node = l:node.parent
        endwhile
        return join(reverse(l:str), '')
    endfunction

    function! l:obj.Reset() abort
        let l:self.string = ''
        let l:self.wildcard_string = ''
        let l:self.current = l:self.trie.root
    endfunction

    function! l:obj.AtEndOfString() abort
        return l:self.current.is_end_of_string
    endfunction

    function! l:obj.AtWildcard() abort
        return l:self.current.char ==# '*'
    endfunction

    function! l:obj.AtRoot() abort
        return l:self.current == l:self.root
    endfunction

    function! l:obj.GetChar() abort
        return l:self.current.char
    endfunction

    function! l:obj.GetString() abort
        return l:self.string
    endfunction

    function! l:obj.GetRoot() abort
        return l:self.root
    endfunction

    function! l:obj.GetParent() abort
        return l:self.current.parent
    endfunction

    function! l:obj.GetCurrent() abort
        return l:self.current
    endfunction

    function! l:obj.GetWildcardString() abort
        return l:self.wildcard_string
    endfunction

    function! l:obj.HasChild(node, char) abort
        return has_key(a:node.children, a:char)
    endfunction

    return l:obj
endfunction

