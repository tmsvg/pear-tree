function! pear_tree#trie#New() abort
    let l:obj = {'root': pear_tree#trie#Node(''),
               \ 'leaves': [],
               \ 'wildcard_symbol': 'wc'}

    function! l:obj.Insert(str) abort
        let l:current = l:self.root
        for l:ch in pear_tree#string#Tokenize(a:str, '*', l:self.wildcard_symbol)
            if !has_key(l:current.children, l:ch)
                let l:node = pear_tree#trie#Node(l:ch)
                let l:current.children[l:ch] = l:node
                let l:node.parent = l:current
            else
                let l:node = get(l:current.children, l:ch)
            endif
            let l:current = l:node
        endfor
        call add(l:self.leaves, l:current)
        let l:current.is_end_of_string = 1
    endfunction

    function! l:obj.GetStrings() abort
        let l:strings = []
        for l:node in l:self.leaves
            call add(l:strings, l:self.GetStringAtNode(l:node))
        endfor
        return l:strings
    endfunction

    function! l:obj.GetStringAtNode(node) abort
        let l:string = []
        let l:current = a:node
        while l:current != l:self.root
            let l:string = add(l:string, l:current.char)
            let l:current = l:current.parent
        endwhile
        return pear_tree#string#Decode(join(reverse(l:string), ''), '*', l:self.wildcard_symbol)
    endfunction

    return l:obj
endfunction


function! pear_tree#trie#Node(char) abort
    let l:obj = {'char': a:char,
               \ 'children': {},
               \ 'parent': {},
               \ 'is_end_of_string': 0}

    function! l:obj.HasChild(char) abort
        return has_key(l:self.children, a:char)
    endfunction

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
        let l:wildcard_node = l:self.current.GetChild(l:self.trie.wildcard_symbol)
        " Try stepping to the node containing a:char.
        if l:node != {}
            let l:self.current = l:node
            let l:self.string = l:self.string . a:char
            return 1
        " Try stepping to a wildcard node.
        elseif l:wildcard_node != {}
            let l:self.current = l:wildcard_node
            let l:self.string = l:self.string . l:self.trie.wildcard_symbol
            let l:self.wildcard_string = l:self.wildcard_string . a:char
            return 1
        elseif l:self.AtWildcard()
            let l:self.wildcard_string = l:self.wildcard_string . a:char
            return 1
        " Reached dead end. Attempt to go back to a wildcard node.
        else
            let l:node = l:self.Backtrack(l:self.trie.wildcard_symbol)
            if l:node != {}
                let l:self.current = l:node
                let l:new_string = l:self.trie.GetStringAtNode(l:self.current)
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
        " An occurrence of the final character of a string means that any
        " time the first character of the string occurs before it, the string
        " is either complete or does not occur. In either case, the traverser
        " would have to reset.
        "
        " For each string in the trie, find the index of the string's opening
        " character that occurs after the most recent occurrence of the final
        " character of the string. Unnecessary resets can be avoided by
        " starting at the smallest of these indices.
        let l:min_idx = a:end
        for l:str in l:self.trie.GetStrings()
            if strlen(l:str) == 1
                continue
            endif
            let l:idx = stridx(a:text, l:str[0], strridx(a:text, l:str[strlen(l:str) - 1], a:end - 1))
            if l:idx < l:min_idx && l:idx >= a:start
                let l:min_idx = l:idx
            endif
        endfor
        let l:i = l:min_idx
        while l:i < a:end
            call l:self.StepOrReset(a:text[(l:i)])
            if l:self.AtWildcard()
                let l:indices = [a:end] + pear_tree#string#FindAll(a:text, keys(l:self.current.children), l:i)
                let l:end_of_wc = min(l:indices) - 1
                let l:self.wildcard_string = l:self.wildcard_string . a:text[(l:i + 1):(l:end_of_wc)]
                let l:i = l:end_of_wc + 1
            elseif l:self.AtRoot()
                let l:indices = [a:end] + pear_tree#string#FindAll(a:text, filter(keys(l:self.root.children), 'l:self.root.GetChild(v:val).children != {}'), l:i)
                let l:i = max([l:i + 1, min(l:indices)])
            else
                let l:i = l:i + 1
            endif
        endwhile
    endfunction

    " Traverse the substring of {text} that begins at {start} and ends at {end}
    " until a character is reached that requires the traverser to reset.
    " Condition                                           Return Value
    " Reached a leaf                                      The index of {text}.
    " Reached the end without reaching a leaf             0
    " Reset before reaching the end                       -1
    function! l:obj.WeakTraverse(text, start, end) abort
        let l:i = a:start
        while l:i < a:end
            if l:self.StepToChild(a:text[(l:i)])
                if l:self.AtEndOfString()
                    return l:i
                endif
            else
                call l:self.Reset()
                return -1
            endif
            if l:self.AtWildcard()
                let l:indices = [a:end] + pear_tree#string#FindAll(a:text, keys(l:self.current.children), l:i)
                let l:end_of_wc = min(l:indices) - 1
                let l:self.wildcard_string = l:self.wildcard_string . a:text[(l:i + 1):(l:end_of_wc)]
                let l:i = l:end_of_wc + 1
            else
                let l:i = l:i + 1
            endif
        endwhile
        return 0
    endfunction

    " Traverse the text in the buffer from {start_pos} to {end_pos}
    " where both positions are given as a tuple of the form
    " [line_number, column_number].
    function! l:obj.TraverseBuffer(start_pos, end_pos)
        " An occurrence of the final character of a string means that any
        " time the first character of the string occurs before it, the string
        " is either complete or does not occur. In either case, the traverser
        " would have to reset.
        "
        " For each string in the trie, find the index of the string's opening
        " character that occurs after the most recent occurrence of the final
        " character of the string. Unnecessary resets can be avoided by
        " starting at the smallest of these indices.
        let l:min_pos = copy(a:end_pos)
        let l:min_not_in = []
        for l:str in l:self.trie.GetStrings()
            if strlen(l:str) == 1
                continue
            endif
            let l:not_in = pear_tree#GetRule(l:str, 'not_in')
            let l:prev_last_char = pear_tree#buffer#ReverseSearch(l:str[strlen(l:str) - 1], a:end_pos, l:not_in)
            let l:search_pos = pear_tree#buffer#Search(l:str[0], l:prev_last_char, l:not_in)
            if l:search_pos == [-1, -1]
                let l:search_pos = pear_tree#buffer#ReverseSearch(l:str[0], a:end_pos, l:not_in)
            endif
            if pear_tree#buffer#ComparePositions(l:search_pos, l:min_pos) < 0
                        \ && pear_tree#buffer#ComparePositions(l:search_pos, a:start_pos) >= 0
                let l:min_not_in = copy(l:not_in)
                let l:min_pos = copy(l:search_pos)
            endif
        endfor
        let l:pos = l:min_pos
        let l:not_in = l:min_not_in
        while pear_tree#buffer#ComparePositions(l:pos, a:end_pos) < 0
            let l:line = getline(l:pos[0])
            call l:self.StepOrReset(l:line[(l:pos[1])])
            if l:self.AtWildcard()
                " Skip to the earliest character that ends the wildcard sequence.
                let l:positions = [a:end_pos]
                for l:char in keys(l:self.current.children)
                    let l:search_pos = pear_tree#buffer#Search(l:char, l:pos, l:not_in)
                    if l:search_pos != [-1, -1]
                        call add(l:positions, l:search_pos)
                    endif
                endfor
                let l:end_of_wildcard = pear_tree#buffer#MinPosition(l:positions)
                let l:end_of_wildcard[1] = l:end_of_wildcard[1] - 1
                if l:end_of_wildcard[0] == l:pos[0]
                    let l:self.wildcard_string .= l:line[l:pos[1] + 1:l:end_of_wildcard[1]]
                else
                    let l:self.wildcard_string .= l:line[(l:pos[1] + 1):]
                    for l:line in getline(l:pos[0] + 1, l:end_of_wildcard[0] - 1)
                        let l:self.wildcard_string = l:self.wildcard_string . l:line
                    endfor
                    let l:self.wildcard_string .= getline(l:end_of_wildcard[0])[:l:end_of_wildcard[1]]
                endif
                let l:pos = copy(l:end_of_wildcard)
                let l:pos[1] = l:pos[1] + 1
            elseif l:self.AtRoot()
                let l:positions = [a:end_pos]
                for l:char in filter(keys(l:self.root.children), 'l:self.root.GetChild(v:val).children != {}')
                    let l:search_pos = pear_tree#buffer#Search(l:char, l:pos, l:not_in)
                    if l:search_pos != [-1, -1]
                        call add(l:positions, l:search_pos)
                    endif
                endfor
                let l:pos = pear_tree#buffer#MinPosition(l:positions)
            else
                let l:pos[1] = l:pos[1] + 1
                if l:pos[1] == strlen(l:line)
                    let l:pos = [l:pos[0] + 1, 0]
                endif
            endif
        endwhile
    endfunction

    " Traverse the text in the buffer from {start_pos} to {end_pos}
    " where both positions are given as a tuple of the form
    " [line_number, column_number], but exit as soon as the traverser is
    " forced to reset. Return the position at which the traverser reached the
    " end of a string or [-1, -1] if it exited early.
    function! l:obj.WeakTraverseBuffer(start_pos, end_pos) abort
        let l:pos = copy(a:start_pos)
        while pear_tree#buffer#ComparePositions(l:pos, a:end_pos) <= 0
            let l:line = getline(l:pos[0])
            if l:self.StepToChild(l:line[l:pos[1]])
                if l:self.AtEndOfString()
                    return l:pos
                endif
            else
                call l:self.Reset()
                return [-1, -1]
            endif
            if l:self.AtWildcard()
                let l:positions = [a:end_pos]
                for l:char in keys(l:self.current.children)
                    let l:str = l:self.trie.GetStringAtNode(l:self.current.GetChild(l:char))
                    if has_key(pear_tree#Pairs(), l:str)
                        let l:not_in = pear_tree#GetRule(l:str, 'not_in')
                    else
                        let l:not_in = []
                    endif
                    let l:search = pear_tree#buffer#Search(l:char, l:pos, l:not_in)
                    if l:search != [-1, -1]
                        call add(l:positions, l:search)
                    endif
                endfor
                let l:end_of_wildcard = pear_tree#buffer#MinPosition(l:positions)
                let l:end_of_wildcard[1] = l:end_of_wildcard[1] - 1
                if l:end_of_wildcard[0] == l:pos[0]
                    let l:self.wildcard_string .= l:line[l:pos[1] + 1:l:end_of_wildcard[1]]
                else
                    let l:self.wildcard_string .= l:line[l:pos[1] + 1:]
                    for l:line in getline(l:pos[0] + 1, l:end_of_wildcard[0] - 1)
                        let l:self.wildcard_string .= l:line
                    endfor
                    let l:self.wildcard_string .= getline(l:end_of_wildcard[0])[:l:end_of_wildcard[1]]
                endif
                let l:pos = l:end_of_wildcard
                let l:pos[1] = l:pos[1] + 1
            else
                let l:pos[1] = l:pos[1] + 1
            endif
        endwhile
        return [-1, -1]
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

    function! l:obj.Reset() abort
        let l:self.string = ''
        let l:self.wildcard_string = ''
        let l:self.current = l:self.trie.root
    endfunction

    function! l:obj.AtEndOfString() abort
        return l:self.current.is_end_of_string
    endfunction

    function! l:obj.AtWildcard() abort
        return l:self.current.char ==# l:self.trie.wildcard_symbol
    endfunction

    function! l:obj.AtRoot() abort
        return l:self.current == l:self.root
    endfunction

    function! l:obj.GetChar() abort
        return l:self.current.char
    endfunction

    function! l:obj.GetString() abort
        return pear_tree#string#Decode(l:self.string, '*', l:self.trie.wildcard_symbol)
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

    return l:obj
endfunction

