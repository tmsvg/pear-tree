" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim


function! pear_tree#trie_traverser#New(trie) abort
    let l:obj = {'trie': a:trie,
               \ 'current': a:trie.root,
               \ 'string': '',
               \ 'wildcard_string': ''}

    let l:obj.StepToChild = function('s:StepToChild')
    let l:obj.StepOrReset = function('s:StepOrReset')
    let l:obj.Reset = function('s:Reset')

    let l:obj.TraverseBuffer = function('s:TraverseBuffer')
    let l:obj.WeakTraverseBuffer = function('s:WeakTraverseBuffer')

    let l:obj.StepToParent = function('s:StepToParent')
    let l:obj.Backtrack = function('s:Backtrack')

    let l:obj.AtEndOfString = function('s:AtEndOfString')
    let l:obj.AtWildcard = function('s:AtWildcard')
    let l:obj.AtRoot = function('s:AtRoot')

    let l:obj.GetString = function('s:GetString')
    let l:obj.GetWildcardString = function('s:GetWildcardString')
    let l:obj.GetCurrent = function('s:GetCurrent')

    return l:obj
endfunction


function! s:StepToChild(char) dict abort
    " Try stepping to the node containing a:char.
    let l:node = pear_tree#trie#GetChild(l:self.current, a:char)
    if l:node != {}
        let l:self.current = l:node
        let l:self.string = l:self.string . a:char
        return 1
    endif
    " Try stepping to a wildcard node.
    let l:wildcard_symbol = l:self.trie.wildcard_symbol
    let l:node = pear_tree#trie#GetChild(l:self.current, l:wildcard_symbol)
    if l:node != {}
        let l:self.current = l:node
        let l:self.string = l:self.string . l:wildcard_symbol
        let l:self.wildcard_string = l:self.wildcard_string . a:char
        return 1
    elseif l:self.AtWildcard()
        let l:self.wildcard_string = l:self.wildcard_string . a:char
        return 1
    endif
    " Reached dead end. Attempt to go back to a wildcard node.
    let l:node = l:self.Backtrack(l:wildcard_symbol)
    if l:node != {}
        let l:self.current = l:node

        let l:string = pear_tree#trie#Prefix(l:self.trie, l:self.current)
        let l:string_len = strlen(l:string)
        let l:string = pear_tree#string#Encode(l:string, '*', l:wildcard_symbol)

        let l:self.wildcard_string = l:self.GetString()[l:string_len - 1:]
        let l:self.string = l:string

        return l:self.StepToChild(a:char)
    else
        return 0
    endif
endfunction


" Attempt to step to {char} in the trie. If this fails, or the traverser is
" already at the end of the trie, reset the traverser.
function! s:StepOrReset(char) dict abort
    if !l:self.StepToChild(a:char)
        call l:self.Reset()
        call l:self.StepToChild(a:char)
    endif
    if l:self.current.children == {} && !l:self.AtWildcard()
        call l:self.Reset()
    endif
endfunction


" Traverse the text in the buffer from {start_pos} to {end_pos}
" where both positions are given as a tuple of the form
" [line_number, column_number].
function! s:TraverseBuffer(start_pos, end_pos) dict abort
    " For each string in the trie, find the position of the string's opening
    " character that occurs after the most recent complete occurrence of the
    " string. By starting at the first of these positions, the amount of text
    " that must be scanned can be greatly reduced.
    let l:min_pos = copy(a:end_pos)
    let l:min_not_in = []
    let l:strings = pear_tree#trie#Strings(l:self.trie)

    for l:str in filter(copy(l:strings), 'strlen(v:val) > 1')
        let l:not_in = pear_tree#GetRule(l:str, 'not_in')
        if pear_tree#string#UnescapedStridx(l:str, '*') > -1
            " An occurrence of the final character of a string with a wildcard
            " part means that any time its first character appears before it,
            " the string is either complete or does not occur. In either case,
            " the traverser would have to reset.
            let l:prev_str_pos = pear_tree#buffer#ReverseSearch(l:str[-1:], [a:end_pos[0], a:end_pos[1] - 1], l:not_in)
            let l:search_pos = pear_tree#buffer#Search(l:str[0], l:prev_str_pos, l:not_in, l:min_pos)
            if l:search_pos == [-1, -1]
                let l:search_pos = pear_tree#buffer#ReverseSearch(l:str[0], a:end_pos, l:not_in)
            endif
        else
            let l:prev_str_pos = [a:end_pos[0], max([a:end_pos[1] - strlen(l:str) - 2, 0])]
            let l:search_pos = pear_tree#buffer#Search(l:str[0], l:prev_str_pos, l:not_in, l:min_pos)
        endif
        if pear_tree#buffer#ComparePositions(l:search_pos, l:min_pos) < 0
                    \ && pear_tree#buffer#ComparePositions(l:search_pos, a:start_pos) >= 0
            let l:min_not_in = copy(l:not_in)
            let l:min_pos = copy(l:search_pos)
        endif
    endfor

    let l:pos = copy(l:min_pos)
    let l:not_in = l:min_not_in

    let l:wildcards = map(filter(copy(l:strings), 'pear_tree#string#UnescapedStridx(v:val, ''*'') > -1'), 'v:val[0]')

    while pear_tree#buffer#ComparePositions(l:pos, a:end_pos) < 0
        let l:line = getline(l:pos[0])
        call l:self.StepOrReset(l:line[l:pos[1]])
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
                let l:self.wildcard_string .= l:line[l:pos[1] + 1:]
                let l:self.wildcard_string .= join(getline(l:pos[0] + 1, l:end_of_wildcard[0] - 1), '')
                let l:self.wildcard_string .= getline(l:end_of_wildcard[0])[:l:end_of_wildcard[1]]
            endif
            let l:pos = copy(l:end_of_wildcard)
            let l:pos[1] = l:pos[1] + 1
        elseif l:self.AtRoot() && l:wildcards != []
            " Find wildcards that precede {end_pos} in the buffer
            let l:positions = [a:end_pos]
            for l:char in l:wildcards
                let l:search_pos = pear_tree#buffer#Search(l:char, l:pos, l:not_in)
                if l:search_pos != [-1, -1]
                            \ && pear_tree#buffer#ComparePositions(l:search_pos, a:end_pos) < 0
                    call add(l:positions, l:search_pos)
                else
                    call remove(l:wildcards, l:char)
                endif
            endfor
            " When no more wildcard strings are found in the buffer, skip to
            " {end_pos} minus the length of the longest string in the trie.
            if l:wildcards == []
                let l:max_len = max(map(copy(l:strings), 'strlen(v:val)'))
                let l:pos = copy(a:end_pos)
                let l:pos[1] = max([0, l:pos[1] - l:max_len])
            else
                let l:pos = pear_tree#buffer#MinPosition(l:positions)
            endif
        else
            let l:pos[1] = l:pos[1] + 1
            if l:pos[1] == strlen(l:line)
                let l:pos = [l:pos[0] + 1, 0]
            endif
        endif
    endwhile
    return l:min_pos
endfunction


" Traverse the text in the buffer from {start_pos} to {end_pos}
" where both positions are given as a tuple of the form
" [line_number, column_number], but exit as soon as the traverser is
" forced to reset. Return the position at which the traverser reached the
" end of a string or [-1, -1] if it exited early.
function! s:WeakTraverseBuffer(start_pos, end_pos) dict abort
    let l:pos = copy(a:start_pos)
    let l:candidate = ''
    let l:candidate_pos = [-1, -1]
    let l:pairs = pear_tree#Pairs()
    while pear_tree#buffer#ComparePositions(l:pos, a:end_pos) < 0
        let l:line = getline(l:pos[0])
        if l:self.StepToChild(l:line[l:pos[1]])
            if l:self.current.is_end_of_string
                if l:self.current.children == {}
                    return l:pos
                else
                    " Reached the end of a string, but it may be a substring
                    " of a longer one. Remember this position, but don't stop.
                    let l:candidate = pear_tree#string#Encode(l:self.string, '*', l:self.wildcard_string)
                    let l:candidate_pos = copy(l:pos)
                endif
            endif
        else
            break
        endif
        if l:self.AtWildcard()
            let l:positions = [a:end_pos]
            let l:str = pear_tree#string#Decode(l:self.string, '*', l:self.trie.wildcard_symbol)
            for l:ch in keys(l:self.current.children)
                if has_key(l:pairs, l:str . l:ch)
                    let l:not_in = pear_tree#GetRule(l:str . l:ch, 'not_in')
                else
                    let l:not_in = []
                endif
                let l:search_pos = pear_tree#buffer#Search(l:ch, l:pos, l:not_in)
                if l:search_pos != [-1, -1]
                    call add(l:positions, l:search_pos)
                endif
            endfor
            let l:end_of_wildcard = pear_tree#buffer#MinPosition(l:positions)
            let l:end_of_wildcard[1] = l:end_of_wildcard[1] - 1
            if l:end_of_wildcard[0] == l:pos[0]
                let l:self.wildcard_string .= l:line[(l:pos[1] + 1):(l:end_of_wildcard[1])]
            else
                let l:self.wildcard_string .= l:line[(l:pos[1] + 1):]
                let l:self.wildcard_string .= join(getline(l:pos[0] + 1, l:end_of_wildcard[0] - 1), '')
                let l:self.wildcard_string .= getline(l:end_of_wildcard[0])[:(l:end_of_wildcard[1])]
            endif
            let l:pos = l:end_of_wildcard
        endif
        let l:pos[1] = l:pos[1] + 1
    endwhile
    " At this point, we failed to reach the end of the string.
    "
    " Did we find a substring of the string that is complete?
    " If so, return its position.
    if l:candidate_pos != [-1, -1]
        call l:self.Reset()
        for l:ch in split(l:candidate, '\zs')
            call l:self.StepOrReset(l:ch)
        endfor
        return l:candidate_pos
    endif
    return [-1, -1]
endfunction


function! s:StepToParent() dict abort
    if l:self.AtWildcard() && l:self.wildcard_string !=# ''
        let l:self.wildcard_string = l:self.wildcard_string[:-2]
    elseif l:self.current.parent != {}
        let l:self.current = l:self.current.parent
        let l:self.string = l:self.string[:-2]
    endif
endfunction


function! s:Backtrack(char) dict abort
    let l:node = l:self.current
    while !has_key(l:node.children, a:char)
        let l:node = l:node.parent
        if l:node == {}
            return {}
        endif
    endwhile
    return pear_tree#trie#GetChild(l:node, a:char)
endfunction


function! s:Reset() dict abort
    let l:self.string = ''
    let l:self.wildcard_string = ''
    let l:self.current = l:self.trie.root
endfunction


function! s:AtEndOfString() dict abort
    return l:self.current.is_end_of_string
endfunction


function! s:AtWildcard() dict abort
    return l:self.current.char ==# l:self.trie.wildcard_symbol
endfunction


function! s:AtRoot() dict abort
    return l:self.current == l:self.trie.root
endfunction


function! s:GetString() dict abort
    return pear_tree#string#Decode(l:self.string, '*', l:self.trie.wildcard_symbol)
endfunction


function! s:GetCurrent() dict abort
    return l:self.current
endfunction


function! s:GetWildcardString() dict abort
    return l:self.wildcard_string
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
