let s:strings_to_expand = []
if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:undo_joiner = "\<C-g>U"
else
    let s:undo_joiner = ''
endif

function! pear_tree#GenerateDelimiter(opener, wildcard_part) abort
    if !has_key(b:pear_tree_pairs, a:opener)
        return ''
    endif
    let l:delim_dict = get(b:pear_tree_pairs, a:opener)
    " Handle the `not_if` rule.
    if has_key(l:delim_dict, 'not_if')
                \ && index(get(l:delim_dict, 'not_if'), a:wildcard_part) > -1
        return ''
    " Handle the `not_in` rule.
    elseif has_key(l:delim_dict, 'not_in')
                \ && index(get(l:delim_dict, 'not_in'), pear_tree#cursor#SyntaxRegion()) > -1
        return ''
    endif
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


function! pear_tree#NextIsBracket() abort
    let l:string_after_cursor = pear_tree#cursor#StringAfter()
    for l:i in values(b:pear_tree_pairs)
        let l:i = get(l:i, 'delimiter')
        if strcharpart(l:string_after_cursor, 0, max([strlen(l:i), 1])) ==# l:i
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


function! pear_tree#HandleTrivialPair(char) abort
    let l:char_after_cursor = pear_tree#cursor#CharAfter()
    let l:char_before_cursor = pear_tree#cursor#CharBefore()
    " Define situations in which Pear Tree is permitted to match.
    " If the cursor is:
    "   1. On an empty line
    "   2. At end of line and not placing dumb pair directly after a word
    "   3. Followed by whitespace and not placing dumb pair directly after a word
    "   4. Between opening and closing pair
    "   5. Before a bracket-type character
    " then we may match the entered character.
    if pear_tree#cursor#OnEmptyLine()
                \ || (pear_tree#cursor#AtEndOfLine() && !(pear_tree#IsDumbPair(a:char) && match(l:char_before_cursor, '\w') > -1))
                \ || (l:char_after_cursor =~# '\s' && !(pear_tree#IsDumbPair(a:char) && match(l:char_before_cursor, '\w') > -1))
                \ || (has_key(b:pear_tree_pairs, l:char_before_cursor) && pear_tree#GetDelimiter(l:char_before_cursor) ==# l:char_after_cursor)
                \ || pear_tree#NextIsBracket()
        let l:closer_string = pear_tree#GenerateDelimiter(a:char, '')
        call pear_tree#insert_mode#Ignore(strlen(a:char . l:closer_string))
        return a:char . l:closer_string . repeat(s:undo_joiner . "\<Left>", pear_tree#util#VisualStringLength(l:closer_string))
    else
        return a:char
    endif
endfunction


function! pear_tree#OnPressDelimiter(char) abort
    if pear_tree#cursor#CharAfter() ==# a:char
        return s:undo_joiner . "\<Right>"
    elseif pear_tree#IsDumbPair(a:char)
        return pear_tree#HandleTrivialPair(a:char)
    else
        return a:char
    endif
endfunction


" Called when pressing the last letter in an opener string.
function! pear_tree#TerminateOpener(char) abort
    " If we entered a 'trivial' pair and are not currently typing a longer
    " strict sequence, handle the trivial pair.
    let l:traverser = pear_tree#insert_mode#GetTraverser()
    if has_key(b:pear_tree_pairs, a:char)
                \ && (l:traverser.GetString() ==# ''
                    \ || l:traverser.AtWildcard()
                    \ || !l:traverser.HasChild(l:traverser.GetCurrent(), a:char)
                    \ )
        if pear_tree#IsDumbPair(a:char)
            return pear_tree#OnPressDelimiter(a:char)
        else
            return pear_tree#HandleTrivialPair(a:char)
        endif
    " Ignore if string ends in wildcard character.
    elseif (l:traverser.AtEndOfString() && l:traverser.AtWildcard())
                \ || (!pear_tree#cursor#AtEndOfLine() && pear_tree#cursor#CharAfter() !~# '\s' && pear_tree#AccurateGetDelimiterAfterCursor() ==# '')
        return a:char
    " Check if stepping to the pressed key in the trie brings us to
    " the end of the string. If so, insert the corresponding closer pair.
    elseif l:traverser.StepToChild(a:char)
        if l:traverser.AtEndOfString()
            let l:opener = l:traverser.GetString()
            let l:closer_string = pear_tree#GenerateDelimiter(l:opener, l:traverser.GetWildcardString())
            let l:closer_str_len = pear_tree#util#VisualStringLength(l:closer_string)
            " The key handler should ignore these key presses
            call pear_tree#insert_mode#Ignore(l:closer_str_len)
            let l:closer_string = a:char . l:closer_string . repeat(s:undo_joiner . "\<Left>", l:closer_str_len)
            return l:closer_string
        else
            return a:char
        endif
    else
        return a:char
    endif
endfunction


function! pear_tree#ExpandOne() abort
    if len(s:strings_to_expand) == 0
        return ''
    endif
    return remove(s:strings_to_expand, -1)
endfunction


function! pear_tree#Expand() abort
    if len(s:strings_to_expand) == 0
        let l:ret_str = "\<Esc>"
    else
        let l:expanded_strings = join(reverse(s:strings_to_expand), "\<CR>")
        let l:ret_str = repeat(s:undo_joiner . "\<Right>", col('$') - col('.'))
                    \ . "\<CR>" . l:expanded_strings . "\<Esc>"
        " Add movement back to correct position
        let l:ret_str = l:ret_str . line('.') . 'gg' . col('.') . '|lh'
    endif
    let s:strings_to_expand = []

    return l:ret_str
endfunction


function! pear_tree#PrepareExpansion() abort
    if pear_tree#AccurateGetDelimiterAfterCursor() !=# ''
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        if strlen(l:text_after_cursor) > 0
            call add(s:strings_to_expand, l:text_after_cursor)
            return repeat("\<Del>", pear_tree#util#VisualStringLength(l:text_after_cursor)) . "\<CR>"
        else
            return "\<CR>"
        endif
    else
        return "\<CR>"
    endif
endfunction


function! pear_tree#PairsInText(text, start, end) abort
    let l:traverser = pear_tree#insert_mode#GetTraverser()
    let l:openers = {}
    let l:pairs = {}
    let l:backtrack = a:start

    while l:backtrack != -1
        call l:traverser.Reset()
        let l:start = l:backtrack

        let l:backtrack = -1

        let l:i = l:start

        for l:char_at_i in split(a:text[(l:start - 1):(a:end - 1)], '\zs')
            if l:traverser.StepToChild(l:char_at_i)
                " Mark position as potential opener to go back to.
                if l:backtrack == -1
                            \ && l:traverser.GetParent() != l:traverser.GetRoot()
                            \ && l:traverser.HasChild(l:traverser.GetRoot(), l:char_at_i)
                    let l:backtrack = l:i
                endif
                if l:traverser.AtEndOfString()
                    let l:opener = l:traverser.GetString()
                    if !has_key(l:openers, l:opener)
                        let l:openers[l:opener] = []
                    endif
                    call add(l:openers[l:opener], [pear_tree#GenerateDelimiter(l:traverser.GetString(), l:traverser.GetWildcardString()), l:i])
                    call l:traverser.Reset()
                endif
            else
                call l:traverser.Reset()
            endif
            let l:i = l:i + 1
        endfor
    endwhile
    for l:key in keys(l:openers)
        let l:index = 0
        for [l:closer, l:i] in reverse(l:openers[l:key])
            if l:closer ==# l:key
                " 'Dumb' pair
                let l:index = stridx(a:text, l:closer, l:i)
            else
                let l:index = stridx(a:text, l:closer, l:index + 1)
            endif
            if l:index != -1
                let l:pairs[l:index] = l:closer
            endif
        endfor
    endfor
    return l:pairs
endfunction


function! pear_tree#AccurateGetDelimiterAfterCursor() abort
    let l:pairs = pear_tree#PairsInText(getline('.'), 1, col('.') - 1)
    if has_key(l:pairs, col('.') - 1)
        return l:pairs[col('.') - 1]
    endif
    return ''
endfunction


function! pear_tree#JumpOut() abort
    let l:closer_string = pear_tree#AccurateGetDelimiterAfterCursor()
    return repeat(s:undo_joiner . "\<Right>", pear_tree#util#VisualStringLength(l:closer_string))
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
