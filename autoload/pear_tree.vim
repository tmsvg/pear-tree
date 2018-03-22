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
    let l:delim = pear_tree#GetDelimiter(a:opener)
    if a:wildcard_part !=# ''
        let l:index = match(a:wildcard_part, l:match_char)
        if l:index == 0
            return ''
        endif
        let l:index = max([-1, l:index - 1])
        let l:delim = substitute(l:delim, '*', a:wildcard_part[:(l:index)], 'g')
    endif
    return l:delim
endfunction


function! pear_tree#IsClosingBracket(char) abort
    for l:delim_dict in values(b:pear_tree_pairs)
        let l:delim = get(l:delim_dict, 'delimiter')
        if a:char ==# l:delim
            return !has_key(b:pear_tree_pairs, l:delim)
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
        let l:delim = pear_tree#GenerateDelimiter(a:char, '')
        return l:delim . repeat(s:LEFT, pear_tree#util#VisualStringLength(l:delim))
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
        let l:delim = pear_tree#GenerateDelimiter(a:opener, a:wildcard_part)
        return l:delim . repeat(s:LEFT, pear_tree#util#VisualStringLength(l:delim))
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


" Return a dictionary of pairs in {text} from {start} to {end}.
"
" The dictionary returned by this function is of the form
"       {delimiter: [openers ...], ...}
" since wildcards allow a single delimiter to be created by various openers,
" but an opener can generate only a single delimiter.
"
" This function does not determine if the pairs in the text are balanced.
function! pear_tree#PairsInText(text, start, end) abort
    let l:traverser = pear_tree#insert_mode#GetTraverser()
    let l:pairs = {}
    let l:children = l:traverser.GetRoot().GetChildren()
    " Find the first occurence of single-character openers and every potential
    " starting point of a multicharacter opener.
    let l:backtrack = pear_tree#util#FindAll(a:text[:(a:end)], filter(keys(l:children), 'l:traverser.GetRoot().GetChild(v:val).GetChildren() == {}'), a:start)
    for l:child in filter(keys(l:children), 'l:traverser.GetRoot().GetChild(v:val).GetChildren() != {}')
        let l:backtrack = l:backtrack + pear_tree#util#FindEvery(a:text[:(a:end)], l:child, a:start)
    endfor
    call add(l:backtrack, a:start)
    while l:backtrack != []
        call l:traverser.Reset()
        let l:i = remove(l:backtrack, -1)
        while l:i < a:end
            if l:traverser.HasChild(l:traverser.GetCurrent(), '*')
                let l:indices = [l:i]
            else
                let l:indices = pear_tree#util#FindAll(a:text, keys(l:traverser.GetCurrent().GetChildren()), l:i)
            endif
            if l:traverser.AtWildcard()
                let l:end_of_wc = l:indices == [] ? (a:end - 1) : (min(l:indices) - 1)
                let l:traverser.wildcard_string = l:traverser.wildcard_string . a:text[(l:i):(l:end_of_wc)]
                let l:i = l:end_of_wc + 1
            elseif l:traverser.AtRoot()
                let l:i = (l:indices == [] ? (a:end) : min(l:indices))
            else
                if l:indices == [] || min(l:indices) > l:i
                    call l:traverser.Reset()
                    continue
                endif
            endif
            if l:traverser.StepToChild(a:text[(l:i)])
                if l:traverser.AtEndOfString()
                    let l:wc_str = l:traverser.GetWildcardString()
                    let l:opener = substitute(l:traverser.GetString(), '*', l:wc_str, 'g')
                    let l:delim = pear_tree#GenerateDelimiter(l:traverser.GetString(), l:wc_str)
                    if l:delim !=# '' && stridx(a:text, l:delim, l:i) != -1
                        if !has_key(l:pairs, l:delim)
                            let l:pairs[l:delim] = []
                        endif
                        call add(l:pairs[l:delim], l:opener)
                    endif
                    break
                endif
            else
                call l:traverser.Reset()
            endif
            let l:i = l:i + 1
        endwhile
    endwhile
    for l:delim in keys(l:pairs)
        let l:pairs[l:delim] = uniq(l:pairs[l:delim])
    endfor
    return l:pairs
endfunction


" Check if the text that directly follows the cursor is a delimiter of a
" balanced pair. If it is, return the delimiter.
function! pear_tree#GetDelimiterAfterCursor() abort
    let l:line = getline('.')
    let l:end = col('.') - 1
    let l:pairs = pear_tree#PairsInText(l:line, 0, l:end)

    call filter(l:pairs, 'stridx(l:line, v:key, l:end) == l:end')

    for l:delim in keys(l:pairs)
        let l:stack = []
        let l:i = l:end
        while l:i >= 0
            let l:opener_indices = []
            for l:opener in l:pairs[l:delim]
                call add(l:opener_indices, strridx(l:line, l:opener, l:i))
            endfor
            let l:next_opener = max(l:opener_indices)
            let l:next_delim = strridx(l:line, l:delim, l:i)

            if l:next_delim != -1 && l:next_delim >= l:next_opener && !(l:stack != [] && pear_tree#IsDumbPair(l:delim))
                call add(l:stack, l:delim)
                let l:i = l:next_delim - 1
            elseif l:next_opener != -1
                if l:stack != []
                    call remove(l:stack, -1)
                    if l:stack == []
                        return l:delim
                    endif
                    let l:i = l:next_opener - 1
                else
                    return ''
                endif
            else
                return ''
            endif
        endwhile
    endfor
    return ''
endfunction


function! pear_tree#JumpOut() abort
    let l:delim = pear_tree#GetDelimiterAfterCursor()
    return repeat(s:RIGHT, pear_tree#util#VisualStringLength(l:delim))
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
