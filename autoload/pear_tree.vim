let s:pear_tree_default_rules = {
            \ 'closer': '',
            \ 'not_in': [],
            \ 'not_if': [],
            \ 'until': '[[:punct:][:space:]]'
            \ }
if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U" . "\<Left>"
    let s:RIGHT = "\<C-g>U" . "\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif

let s:strings_to_expand = []


function! pear_tree#Pairs() abort
    return deepcopy(get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs')))
endfunction


function! pear_tree#GetRule(opener, rule) abort
    let l:rules = get(pear_tree#Pairs(), a:opener)
    return get(l:rules, a:rule, s:pear_tree_default_rules[a:rule])
endfunction


function! pear_tree#IsDumbPair(char) abort
    return has_key(pear_tree#Pairs(), a:char) && pear_tree#GetRule(a:char, 'closer') ==# a:char
endfunction


function! pear_tree#GenerateCloser(opener, wildcard, position) abort
    if !has_key(pear_tree#Pairs(), a:opener)
        return ''
    endif
    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    if (a:position[0] > 0 && l:not_in != []
                \ && pear_tree#buffer#SyntaxRegion(a:position) =~? join(l:not_in, '\|'))
        return ''
    endif
    let l:closer = pear_tree#GetRule(a:opener, 'closer')
    if a:wildcard ==# ''
        return pear_tree#string#Encode(l:closer, '*', '')
    endif
    let l:until = pear_tree#GetRule(a:opener, 'until')
    if l:until ==# ''
        let l:index = strlen(a:wildcard)
    else
        let l:index = match(a:wildcard, l:until)
        if l:index == 0
            return ''
        endif
    endif
    let l:trimmed_wildcard = a:wildcard[:max([-1, l:index - 1])]
    if index(pear_tree#GetRule(a:opener, 'not_if'), l:trimmed_wildcard) > -1
        return ''
    endif
    " Replace unescaped * chars with the wildcard string.
    return pear_tree#string#Encode(l:closer, '*', l:trimmed_wildcard)
endfunction


" Check if {opener} is balanced in the buffer. If it is, return the position
" of the final character of the opener that balances the pair. If the pair is
" unbalanced, return [-1, -1].
"
" An optional argument {skip_count} tells the function to ignore the first
" {skip_count} openers. This can be used to see if the closer at {start}
" would be balanced if the previous {skip_count} openers were deleted.
function! pear_tree#IsBalancedPair(opener, wildcard, start, ...) abort
    let l:count = a:0 ? a:1 : 0

    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    " The syntax region at {start} should always be included in searches.
    call filter(l:not_in, 'pear_tree#buffer#SyntaxRegion(a:start) !~? v:val')

    " It's not feasible to accurately determine if dumb pairs are balanced in
    " the buffer, so do a simple check and leave quickly.
    if pear_tree#IsDumbPair(a:opener)
        return pear_tree#buffer#ReverseSearch(a:opener, [a:start[0], a:start[1] - 1], l:not_in)
    endif

    " Generate a hint to find openers faster. Since {wildcard} is obtained
    " from the closer, it might be a trimmed version of the opener's.
    let l:idx = pear_tree#string#UnescapedStridx(a:opener, '*')
    let l:opener_hint = pear_tree#string#Encode(a:opener[:(l:idx)], '*', a:wildcard)

    let l:has_wildcard = (l:idx != -1)
    if l:has_wildcard
        let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
        let l:traverser = pear_tree#trie#Traverser(l:trie)
    endif

    let l:closer = pear_tree#GenerateCloser(a:opener, a:wildcard, a:start)

    let l:current_pos = a:start
    let l:closer_pos = [l:current_pos[0], l:current_pos[1] + 1]
    let l:opener_pos = [l:current_pos[0], l:current_pos[1] + 1]
    while l:current_pos[0] > -1
        " Find the previous opener and closer in the buffer.
        if pear_tree#buffer#ComparePositions(l:opener_pos, l:current_pos) > 0
            if l:has_wildcard
                let l:search_pos = copy(l:current_pos)
                while l:search_pos[0] > -1
                    call l:traverser.Reset()
                    let l:search_pos = pear_tree#buffer#ReverseSearch(l:opener_hint, l:search_pos)
                    let l:end_pos = l:traverser.WeakTraverseBuffer(l:search_pos, l:opener_pos)
                    if l:end_pos[0] != -1
                                \ && pear_tree#GenerateCloser(l:traverser.GetString(), l:traverser.GetWildcardString(), [0, 0]) ==# l:closer
                        break
                    endif
                    let l:search_pos[1] = l:search_pos[1] - 1
                endwhile
                let l:opener_pos = l:end_pos
            else
                let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener_hint, l:current_pos, l:not_in)
            endif
        endif
        if pear_tree#buffer#ComparePositions(l:closer_pos, l:current_pos) > 0
            let l:closer_pos = pear_tree#buffer#ReverseSearch(l:closer, l:current_pos, l:not_in)
        endif
        if l:closer_pos[0] != -1
                    \ && pear_tree#buffer#ComparePositions([l:closer_pos[0], l:closer_pos[1] + strlen(l:closer) - 1], l:opener_pos) >= 0
            let l:count = l:count + 1
            let l:current_pos = [l:closer_pos[0], l:closer_pos[1] - 1]
        elseif l:opener_pos[0] != -1 && l:count != 0
            let l:count = l:count - 1
            if l:count == 0
                return l:has_wildcard ? l:opener_pos
                                    \ : [l:opener_pos[0], l:opener_pos[1] + strlen(l:opener_hint) - 1]
            endif
            let l:current_pos = [l:opener_pos[0], l:opener_pos[1] - 1]
        else
            return [-1, -1]
        endif
    endwhile
    return [-1, -1]
endfunction


" Return the opener and closer that surround the cursor, as well as the
" wildcard string and the position of the opener.
function! pear_tree#GetSurroundingPair() abort
    let l:closers = map(keys(pear_tree#Pairs()), 'pear_tree#GetRule(v:val, ''closer'')')
    let l:closer_trie = pear_tree#trie#New(l:closers)
    let l:closer_traverser = pear_tree#trie#Traverser(l:closer_trie)

    let l:start = l:closer_traverser.WeakTraverseBuffer([line('.'), col('.') - 1], pear_tree#buffer#End())
    if l:start[0] == -1
        return []
    endif
    let l:closer = l:closer_traverser.GetString()
    let l:wildcard = l:closer_traverser.GetWildcardString()
    for l:opener in keys(filter(pear_tree#Pairs(), 'v:val.closer ==# l:closer'))
        let l:pos = pear_tree#IsBalancedPair(l:opener, l:wildcard, l:start)
        if l:pos[0] != -1
            return [l:opener, l:closer, l:wildcard, l:pos]
        endif
    endfor
    return []
endfunction


function! pear_tree#Backspace() abort
    let l:prev_char = pear_tree#cursor#PrevChar()
    if !has_key(pear_tree#Pairs(), l:prev_char)
        return "\<BS>"
    endif
    let l:next_char = pear_tree#cursor#NextChar()

    if pear_tree#GetRule(l:prev_char, 'closer') !=# l:next_char
        let l:should_delete_both = 0
    elseif pear_tree#IsDumbPair(l:prev_char)
        let l:should_delete_both = 1
    elseif get(g:, 'pear_tree_smart_backspace', get(b:, 'pear_tree_smart_backspace', 0))
        " Get the first closer after the cursor not preceded by an opener.
        let l:not_in = pear_tree#GetRule(l:prev_char, 'not_in')

        let l:opener_pos = pear_tree#buffer#Search(l:prev_char, pear_tree#cursor#Position(), l:not_in)
        let l:closer_pos = pear_tree#buffer#Search(l:next_char, pear_tree#cursor#Position(), l:not_in)
        while pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                    \ && l:opener_pos != [-1, -1]
            let l:opener_pos[1] += 1
            let l:closer_pos[1] += 1
            let l:opener_pos = pear_tree#buffer#Search(l:prev_char, l:opener_pos, l:not_in)
            let l:closer_pos = pear_tree#buffer#Search(l:next_char, l:closer_pos, l:not_in)
        endwhile
        if l:opener_pos == [-1, -1]
            let l:opener_pos = pear_tree#buffer#End()
        endif
        let l:closer_pos = pear_tree#buffer#ReverseSearch(l:next_char, l:opener_pos, l:not_in)
        " Will deleting both make the next closer unbalanced?
        let l:should_delete_both = (pear_tree#IsBalancedPair(l:prev_char, '', l:closer_pos, 1) == [-1, -1])
    else
        let l:should_delete_both = 1
    endif
    if l:should_delete_both
        return "\<Del>\<BS>"
    else
        return "\<BS>"
    endif
endfunction


function! pear_tree#PrepareExpansion() abort
    let l:prev_char = pear_tree#cursor#PrevChar()
    if filter(keys(pear_tree#Pairs()), 'v:val[-1:] ==# l:prev_char') == []
        return "\<CR>"
    endif
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return "\<CR>"
    endif
    let l:cursor_pos = pear_tree#cursor#Position()
    let [l:opener, l:closer, l:wildcard, l:opener_pos] = l:pair
    let l:closer = pear_tree#GenerateCloser(l:opener, l:wildcard, l:cursor_pos)
    if l:opener_pos[0] == l:cursor_pos[0] && l:opener_pos[1] == l:cursor_pos[1] - 2
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        call add(s:strings_to_expand, l:text_after_cursor)
        return repeat("\<Del>", pear_tree#string#VisualLength(l:text_after_cursor)) . "\<CR>"
    else
        return "\<CR>"
    endif
endfunction


function! pear_tree#Expand() abort
    if s:strings_to_expand == []
        return "\<Esc>"
    else
        let l:expanded_strings = join(reverse(s:strings_to_expand), "\<CR>")
        let s:strings_to_expand = []
        let [l:lnum, l:col] = pear_tree#cursor#Position()
        return repeat(s:RIGHT, col('$') - l:col)
                    \ . "\<CR>" . l:expanded_strings . "\<Esc>"
                    \ . l:lnum . 'gg' . l:col . '|lh'
    endif
endfunction


function! pear_tree#JumpOut() abort
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return ''
    endif
    let [l:opener, l:closer, l:wildcard] = l:pair[:2]
    let l:closer = pear_tree#GenerateCloser(l:opener, l:wildcard, pear_tree#cursor#Position())
    return repeat(s:RIGHT, pear_tree#string#VisualLength(l:closer))
endfunction


function! pear_tree#JumpNReturn() abort
    return pear_tree#JumpOut() . "\<CR>"
endfunction


function! pear_tree#ExpandOne() abort
    if s:strings_to_expand == []
        return ''
    endif
    return remove(s:strings_to_expand, -1)
endfunction
