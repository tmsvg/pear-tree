let s:pear_tree_default_rules = {
            \ 'delimiter': '',
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


function! pear_tree#PairTrie()
    let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
    return l:trie
endfunction


function! pear_tree#Pairs() abort
    return get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
endfunction


function! pear_tree#GetRule(opener, rule) abort
    let l:rules = get(pear_tree#Pairs(), a:opener)
    return get(l:rules, a:rule, s:pear_tree_default_rules[a:rule])
endfunction


function! pear_tree#IsDumbPair(char) abort
    return has_key(pear_tree#Pairs(), a:char) && pear_tree#GetRule(a:char, 'delimiter') ==# a:char
endfunction


function! pear_tree#GenerateDelimiter(opener, wildcard, position) abort
    if !has_key(pear_tree#Pairs(), a:opener)
        return ''
    endif
    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    if (a:position[0] > 0 && l:not_in != []
                \ && pear_tree#buffer#SyntaxRegion(a:position) =~? join(l:not_in, '\|'))
        return ''
    elseif index(pear_tree#GetRule(a:opener, 'not_if'), a:wildcard) > -1
        return ''
    endif
    let l:delim = pear_tree#GetRule(a:opener, 'delimiter')
    if a:wildcard ==# ''
        return pear_tree#string#Encode(l:delim, '*', '')
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
    let l:index = max([-1, l:index - 1])
    " Replace unescaped * chars with the wildcard string.
    return pear_tree#string#Encode(l:delim, '*', a:wildcard[:(l:index)])
endfunction


" Check if {opener} is balanced in the buffer. If it is, return the position
" of the final character of the opener that balances the pair. If the pair is
" unbalanced, return [-1, -1].
"
" An optional argument {skip_count} tells the function to ignore the first
" {skip_count} openers. This can be used to see if the delimiter at {start}
" would be balanced if the previous {skip_count} openers were deleted.
function! pear_tree#IsBalancedPair(opener, wildcard, start, ...) abort
    let l:count = a:0 ? a:1 : 0

    if a:wildcard !=# ''
        " Generate a hint to find openers faster when the pair contains a
        " wildcard. The {wildcard} is the wildcard string as it appears in the
        " delimiter, so it may be a trimmed version of the opener's wildcard.
        let l:opener_hint = a:opener[:pear_tree#string#UnescapedStridx(a:opener, '*')]
        let l:opener_hint = pear_tree#string#Encode(l:opener_hint, '*', a:wildcard)
        let l:traverser = pear_tree#trie#Traverser(pear_tree#PairTrie())
    else
        " Unescape asterisks
        let l:opener_hint = pear_tree#string#Encode(a:opener, '*', '')
    endif
    let l:delim = pear_tree#GenerateDelimiter(a:opener, a:wildcard, a:start)

    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')

    let l:current_pos = a:start
    let l:delim_pos = [l:current_pos[0], l:current_pos[1] + 1]
    let l:opener_pos = [l:current_pos[0], l:current_pos[1] + 1]
    while l:current_pos[0] > -1
        " Find the previous opener and delimiter in the buffer.
        if pear_tree#buffer#ComparePositions(l:opener_pos, l:current_pos) > 0
            if a:wildcard ==# ''
                let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener_hint, l:current_pos, l:not_in)
            else
                " Search for the opener hint and ensure it is a valid opener.
                let l:search_pos = [l:current_pos[0], l:current_pos[1]]
                while l:search_pos[0] > -1
                    call l:traverser.Reset()
                    " Don't worry about `not_in` regions for the search. The
                    " traverser will handle them.
                    let l:search_pos = pear_tree#buffer#ReverseSearch(l:opener_hint, l:search_pos)
                    let l:end_pos = l:traverser.WeakTraverseBuffer(l:search_pos, l:opener_pos)
                    if l:end_pos[0] != -1
                                \ && pear_tree#GenerateDelimiter(l:traverser.GetString(), l:traverser.GetWildcardString(), [0, 0]) ==# l:delim
                        break
                    endif
                    let l:search_pos[1] = l:search_pos[1] - 1
                endwhile
                let l:opener_pos = l:search_pos
            endif
        endif
        if pear_tree#buffer#ComparePositions(l:delim_pos, l:current_pos) > 0
            let l:delim_pos = pear_tree#buffer#ReverseSearch(l:delim, l:current_pos, l:not_in)
        endif
        if l:delim_pos[0] != -1
                    \ && pear_tree#buffer#ComparePositions(l:delim_pos, l:opener_pos) >= 0
                    \ && !(l:count != 0 && pear_tree#IsDumbPair(l:delim))
            let l:count = l:count + 1
            let l:current_pos = [l:delim_pos[0], l:delim_pos[1] - 1]
        elseif l:opener_pos[0] != -1 && l:count != 0
            let l:count = l:count - 1
            if l:count == 0
                return a:wildcard ==# '' ? [l:opener_pos[0], l:opener_pos[1] + strlen(l:opener_hint) - 1]
                                       \ : l:end_pos
            endif
            let l:current_pos = [l:opener_pos[0], l:opener_pos[1] - 1]
        else
            return [-1, -1]
        endif
    endwhile
    return [-1, -1]
endfunction


" Return the opener and delimiter that surround the cursor, as well as the
" wildcard string and the position of the opener.
function! pear_tree#GetSurroundingPair() abort
    let l:delims = map(keys(pear_tree#Pairs()), 'pear_tree#GetRule(v:val, ''delimiter'')')
    let l:delim_trie = pear_tree#trie#New(l:delims)
    let l:delim_traverser = pear_tree#trie#Traverser(l:delim_trie)
    let l:start = l:delim_traverser.WeakTraverseBuffer([line('.'), col('.') - 1], pear_tree#buffer#End())
    if l:start[0] == -1
        return []
    endif
    let l:delim = l:delim_traverser.GetString()
    let l:wildcard = l:delim_traverser.GetWildcardString()
    for l:opener in keys(pear_tree#Pairs())
        if pear_tree#GetRule(l:opener, 'delimiter') ==# l:delim
            let l:pos = pear_tree#IsBalancedPair(l:opener, l:wildcard, l:start)
            if l:pos[0] != -1
                return [l:opener, l:delim, l:wildcard, l:pos]
            endif
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

    if pear_tree#GetRule(l:prev_char, 'delimiter') !=# l:next_char
        let l:should_delete_both = 0
    elseif pear_tree#IsDumbPair(l:prev_char)
        let l:should_delete_both = 1
    elseif get(g:, 'pear_tree_smart_backspace', get(b:, 'pear_tree_smart_backspace', 0))
        " Get the first delimiter after the cursor not preceded by an opener.
        let l:not_in = pear_tree#GetRule(l:prev_char, 'not_in')

        let l:opener_pos = pear_tree#buffer#Search(l:prev_char, pear_tree#cursor#Position(), l:not_in)
        let l:delim_pos = pear_tree#buffer#Search(l:next_char, pear_tree#cursor#Position(), l:not_in)
        if l:opener_pos != [-1, -1]
            while pear_tree#buffer#ComparePositions(l:opener_pos, l:delim_pos) < 0
                        \ && l:opener_pos != [-1, -1]
                let l:opener_pos[1] += 1
                let l:delim_pos[1] += 1
                let l:opener_pos = pear_tree#buffer#Search(l:prev_char, l:opener_pos, l:not_in)
                let l:delim_pos = pear_tree#buffer#Search(l:next_char, l:delim_pos, l:not_in)
            endwhile
        endif
        let l:delim_pos = pear_tree#buffer#ReverseSearch(l:next_char, l:opener_pos, l:not_in)
        if l:delim_pos[0] == -1
            let l:delim_pos = pear_tree#buffer#End()
        endif
        " Will deleting both make the next delimiter unbalanced?
        let l:should_delete_both = (pear_tree#IsBalancedPair(l:prev_char, '', l:delim_pos, 1) == [-1, -1])
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
    let l:cursor_pos = pear_tree#cursor#Position()

    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return "\<CR>"
    endif
    let [l:opener, l:delim, l:wildcard, l:opener_pos] = l:pair
    let l:delim = pear_tree#GenerateDelimiter(l:opener, l:wildcard, l:cursor_pos)
    if (l:opener_pos[0] == l:cursor_pos[0]) && (l:opener_pos[1] + 1 == l:cursor_pos[1] - 1)
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        call add(s:strings_to_expand, l:text_after_cursor)
        return repeat("\<Del>", pear_tree#string#VisualLength(l:text_after_cursor)) . "\<CR>"
    else
        return "\<CR>"
    endif
endfunction


function! pear_tree#Expand() abort
    if s:strings_to_expand == []
        let l:ret_str = "\<Esc>"
    else
        let l:expanded_strings = join(reverse(s:strings_to_expand), "\<CR>")
        let l:ret_str = repeat(s:RIGHT, col('$') - col('.')) . "\<CR>" . l:expanded_strings . "\<Esc>"
        " Add movement back to correct position
        let l:ret_str = l:ret_str . line('.') . 'gg' . col('.') . '|lh'
        let s:strings_to_expand = []
    endif
    return l:ret_str
endfunction


function! pear_tree#JumpOut() abort
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return ''
    endif
    let [l:opener, l:delim, l:wildcard] = l:pair[:2]
    let l:delim = pear_tree#GenerateDelimiter(l:opener, l:wildcard, pear_tree#cursor#Position())
    return repeat(s:RIGHT, pear_tree#string#VisualLength(l:delim))
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
