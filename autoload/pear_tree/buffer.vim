function! s:ShouldSkip(position, skip_list)
    return a:skip_list != [] && index(a:skip_list, pear_tree#buffer#SyntaxRegion(a:position)) > -1
endfunction

" Search through the buffer for {string} beginning at {start_position}.
function! pear_tree#buffer#Search(string, start_position, ...) abort
    let l:skip_regions = a:0 ? a:1 : []
    let l:line = a:start_position[0]
    let l:col = stridx(getline(l:line), a:string, a:start_position[1])
    while l:line < line('$') && (l:col == -1 || s:ShouldSkip([l:line, l:col + 1], l:skip_regions))
        let l:line = l:line + 1
        let l:col = stridx(getline(l:line), a:string)
    endwhile
    return (l:col == -1 || s:ShouldSkip([l:line, l:col + 1], l:skip_regions)) ? [-1, -1] : [l:line, l:col]
endfunction


" Search backwards through the buffer for {string} beginning at
" {start_position}.
function! pear_tree#buffer#ReverseSearch(string, start_position, ...) abort
    let l:skip_regions = a:0 ? a:1 : []
    let l:line = a:start_position[0]
    let l:col = strridx(getline(l:line), a:string, a:start_position[1])
    while l:line > 1 && (l:col == -1 || s:ShouldSkip([l:line, l:col + 1], l:skip_regions))
        let l:line = l:line - 1
        let l:col = strridx(getline(l:line), a:string)
    endwhile
    return (l:col == -1 || s:ShouldSkip([l:line, l:col + 1], l:skip_regions)) ? [-1, -1] : [l:line, l:col]
endfunction


" Given two positions of the form [line_number, column_number], return 1 if
" {pos1} occurs after {pos2} in the buffer, 0 if the positions are equal and
" -1 if {pos1} occurs before {pos2} in the buffer.
function! pear_tree#buffer#ComparePositions(pos1, pos2) abort
    if a:pos1[0] == a:pos2[0]
        if a:pos1[1] > a:pos2[1]
            return 1
        elseif a:pos1[1] == a:pos2[1]
            return 0
        else
            return -1
        endif
    elseif a:pos1[0] > a:pos2[0]
        return 1
    else
        return -1
    endif
endfunction


function! pear_tree#buffer#SyntaxRegion(position) abort
    return synIDattr(synIDtrans(synID(a:position[0], a:position[1], 1)), 'name')
endfunction
