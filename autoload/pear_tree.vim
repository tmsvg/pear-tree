let s:strings_to_expand = []
if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U" . "\<Left>"
    let s:RIGHT = "\<C-g>U" . "\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif


function! pear_tree#GenerateDelimiter(opener, wildcard_part) abort
    if !has_key(b:pear_tree_pairs, a:opener)
        return ''
    endif
    let l:delim_dict = get(b:pear_tree_pairs, a:opener)
    " Handle the `until` rule.
    if has_key(l:delim_dict, 'until')
        let l:match_char = get(l:delim_dict, 'until')
    else
        let l:match_char = '[[:punct:][:space:]]'
    endif
    let l:closer_string = pear_tree#GetDelimiter(a:opener)
    if a:wildcard_part !=# ''
        let l:index = match(a:wildcard_part, l:match_char)
        if l:index == 0
            return ''
        endif
        let l:index = max([-1, l:index - 1])
        let l:closer_string = substitute(l:closer_string, '*', a:wildcard_part[:(l:index)], 'g')
    endif
    return l:closer_string
endfunction


function! pear_tree#IsClosingBracket(char) abort
    for l:i in values(b:pear_tree_pairs)
        let l:i = get(l:i, 'delimiter')
        if a:char ==# l:i
            return !has_key(b:pear_tree_pairs, l:i)
        endif
    endfor
    return 0
endfunction


function! pear_tree#IsDumbPair(char) abort
    return has_key(b:pear_tree_pairs, a:char) && pear_tree#GetDelimiter(a:char) ==# a:char
endfunction


function! pear_tree#GetDelimiter(char) abort
    return get(get(b:pear_tree_pairs, a:char), 'delimiter')
endfunction


function! pear_tree#HandleSimplePair(char) abort
    let l:delim_dict = get(b:pear_tree_pairs, a:char)
    let l:char_after_cursor = pear_tree#cursor#CharAfter()
    let l:char_before_cursor = pear_tree#cursor#CharBefore()
    if has_key(l:delim_dict, 'not_in') && index(get(l:delim_dict, 'not_in'), pear_tree#cursor#SyntaxRegion()) > -1
        return ''
    " Define situations in which Pear Tree is permitted to match.
    " If the cursor is:
    "   1. On an empty line
    "   2. At end of line and not placing dumb pair directly after a word
    "   3. Followed by whitespace and not placing dumb pair directly after a word
    "   4. Between opening and closing pair
    "   5. Before a bracket-type character
    " then we may match the entered character.
    elseif pear_tree#cursor#OnEmptyLine()
                \ || !(pear_tree#IsDumbPair(a:char) && match(l:char_before_cursor, '\w') > -1) && (pear_tree#cursor#AtEndOfLine()
                                                                                             \ || l:char_after_cursor =~# '\s')
                \ || (has_key(b:pear_tree_pairs, l:char_before_cursor) && pear_tree#GetDelimiter(l:char_before_cursor) ==# l:char_after_cursor)
                \ || pear_tree#IsClosingBracket(l:char_after_cursor)
        let l:closer_string = pear_tree#GenerateDelimiter(a:char, '')
        return l:closer_string . repeat(s:LEFT, pear_tree#util#VisualStringLength(l:closer_string))
    else
        return ''
    endif
endfunction


function! pear_tree#HandleComplexPair(opener, wildcard_part) abort
    let l:delim_dict = get(b:pear_tree_pairs, a:opener)
    " Handle rules
    if (has_key(l:delim_dict, 'not_if') && index(get(l:delim_dict, 'not_if'), a:wildcard_part) > -1)
                \ || (has_key(l:delim_dict, 'not_in') && index(get(l:delim_dict, 'not_in'), pear_tree#cursor#SyntaxRegion()) > -1)
        return ''
    elseif (pear_tree#cursor#AtEndOfLine()
                \ || pear_tree#cursor#CharAfter() =~# '\s'
                \ || pear_tree#GetDelimiterAfterCursor() !=# '')
        let l:closer_string = pear_tree#GenerateDelimiter(a:opener, a:wildcard_part)
        return l:closer_string . repeat(s:LEFT, pear_tree#util#VisualStringLength(l:closer_string))
    else
        return ''
    endif
endfunction


function! pear_tree#OnPressDelimiter(char) abort
    if pear_tree#cursor#CharAfter() ==# a:char
        return s:RIGHT
    elseif pear_tree#IsDumbPair(a:char)
        return a:char . pear_tree#HandleSimplePair(a:char)
    else
        return a:char
    endif
endfunction


" Called when pressing the last letter in an opener string.
function! pear_tree#TerminateOpener(char) abort
    " If entered a simple (length of 1) opener and not currently typing
    " a longer strict sequence, handle the trivial pair.
    let l:traverser = pear_tree#insert_mode#GetTraverser()
    if has_key(b:pear_tree_pairs, a:char)
                \ && (l:traverser.GetString() ==# ''
                    \ || l:traverser.AtWildcard()
                    \ || !l:traverser.HasChild(l:traverser.GetCurrent(), a:char)
                    \ )
        if pear_tree#IsDumbPair(a:char)
            return pear_tree#OnPressDelimiter(a:char)
        else
            return a:char . pear_tree#HandleSimplePair(a:char)
        endif
    elseif l:traverser.StepToChild(a:char) && l:traverser.AtEndOfString()
        let l:opener = l:traverser.GetString()
        if has_key(b:pear_tree_pairs, l:opener)
            return a:char . pear_tree#HandleComplexPair(l:opener, l:traverser.GetWildcardString())
        else
            return a:char
        endif
    else
        return a:char
    endif
endfunction


function! pear_tree#ExpandOne() abort
    if s:strings_to_expand == []
        return ''
    endif
    return remove(s:strings_to_expand, -1)
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


function! pear_tree#PrepareExpansion() abort
    let l:delim = pear_tree#GetDelimiterAfterCursor()
    if l:delim !=# '' && !pear_tree#IsDumbPair(l:delim)
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        call add(s:strings_to_expand, l:text_after_cursor)
        return repeat("\<Del>", pear_tree#util#VisualStringLength(l:text_after_cursor)) . "\<CR>"
    else
        return "\<CR>"
    endif
endfunction


function! pear_tree#PairsInText(text, start, end) abort
    let l:traverser = pear_tree#insert_mode#GetTraverser()
    let l:backtrack = [a:start]
    let l:pairs = {}
    while l:backtrack != []
        call l:traverser.Reset()
        let l:start = remove(l:backtrack, -1)
        let l:i = l:start
        for l:char_at_i in split(a:text[(l:start - 1):(a:end - 1)], '\zs')
            if l:traverser.StepToChild(l:char_at_i)
                " Mark position as potential opener to go back to.
                if l:start == a:start
                            \ && l:traverser.GetParent() != l:traverser.GetRoot()
                            \ && l:traverser.HasChild(l:traverser.GetRoot(), l:char_at_i)
                    call add(l:backtrack, l:i)
                endif
                if l:traverser.AtEndOfString()
                    let l:wc_str = l:traverser.GetWildcardString()
                    let l:opener = substitute(l:traverser.GetString(), '*', l:wc_str, 'g')
                    let l:closer = pear_tree#GenerateDelimiter(l:traverser.GetString(), l:wc_str)
                    if l:closer !=# ''
                        if !has_key(l:pairs, l:closer)
                            let l:pairs[l:closer] = []
                        endif
                        call add(l:pairs[l:closer], l:opener)
                    endif
                    if l:start != a:start
                        break
                    endif
                    call l:traverser.Reset()
                endif
            else
                call l:traverser.Reset()
            endif
            let l:i = l:i + 1
        endfor
    endwhile
    return l:pairs
endfunction


function! pear_tree#GetDelimiterAfterCursor() abort
    let l:line = getline('.')
    let l:end = col('.') - 1
    let l:pairs = pear_tree#PairsInText(l:line, 1, l:end)

    call filter(l:pairs, 'stridx(l:line, v:key, l:end) == l:end')
    for l:closer in keys(l:pairs)
        let l:stack = []
        let l:i = l:end
        while l:i >= 0
            let l:decrement = 1
            if stridx(l:line, l:closer, l:i) == l:i && !(l:stack != [] && pear_tree#IsDumbPair(l:closer))
                call add(l:stack, l:closer)
                let l:decrement = strlen(l:closer)
            else
                for l:opener in uniq(l:pairs[l:closer])
                    if stridx(l:line, l:opener, l:i) == l:i
                        if l:stack == []
                            return ''
                        else
                            call remove(l:stack, -1)
                            if l:stack == []
                                return l:closer
                            endif
                            let l:decrement = strlen(l:opener)
                        endif
                        break
                    endif
                endfor
            endif
            let l:i = l:i - max([l:decrement - 1, 1])
        endwhile
    endfor
    return ''
endfunction


function! pear_tree#JumpOut() abort
    let l:closer_string = pear_tree#GetDelimiterAfterCursor()
    return repeat(s:RIGHT, pear_tree#util#VisualStringLength(l:closer_string))
endfunction


function! pear_tree#JumpNReturn() abort
    return pear_tree#JumpOut() . "\<CR>"
endfunction


function! pear_tree#Backspace() abort
    let l:char_after_cursor = pear_tree#cursor#CharAfter()
    let l:char_before_cursor = pear_tree#cursor#CharBefore()
    if has_key(b:pear_tree_pairs, l:char_before_cursor)
                \ && l:char_after_cursor ==# get(b:pear_tree_pairs, l:char_before_cursor)['delimiter']
        return "\<Del>\<BS>"
    endif
    return "\<BS>"
endfunction
