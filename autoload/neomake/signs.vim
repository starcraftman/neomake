" vim: ts=4 sw=4 et

function! neomake#signs#CleanBuffer() abort
    let b:neomake_signs = get(b:, 'neomake_signs', {})
    for ln in keys(b:neomake_signs)
        exe 'sign unplace '.b:neomake_signs[ln]
    endfor
    let b:neomake_signs = {}
endfunction

function! neomake#signs#GetSigns(...) abort
    let signs = {
        \ 'by_line': {},
        \ 'max_id': 0,
        \ }
    if a:0
        let opts = a:1
    else
        let opts = {}
    endif
    let place_cmd = 'sign place'
    for attr in keys(opts)
        if attr ==# 'file' || attr ==# 'buffer'
            let place_cmd .= ' '.attr.'='.opts[attr]
        endif
    endfor
    call neomake#utils#DebugMessage('executing: '.place_cmd)
    redir => signs_txt | silent exe place_cmd | redir END
    let fname_pattern = 'Signs for \(.*\):'
    for s in split(signs_txt, '\n')
        if s =~# fname_pattern
            " This should always happen first, so don't define outside loop
            let fname = substitute(s, fname_pattern, '\1', '')
        elseif s =~# 'id='
            let result = {}
            let parts = split(s, '\s\+')
            for part in parts
                let [key, val] = split(part, '=')
                let result[key] = val =~# '\d\+' ? 0 + val : val
            endfor
            let result.file = fname
            if !has_key(opts, 'name') || opts.name ==# result.name
                let signs.by_line[result.line] = get(signs.by_line, result.line, [])
                call add(signs.by_line[result.line], result)
                let signs.max_id = max([signs.max_id, result.id])
            endif
        endif
    endfor
    return signs
endfunction

function! neomake#signs#GetSignsInBuffer(bufnr) abort
    return neomake#signs#GetSigns({'buffer': a:bufnr})
endfunction

function! neomake#signs#PlaceSign(existing_signs, entry) abort
    let type = a:entry.type ==# 'E' ? 'neomake_err' : 'neomake_warn'

    let a:existing_signs.by_line[a:entry.lnum] = get(l:signs.by_line, a:entry.lnum, [])
    if !has_key(b:neomake_signs, a:entry.lnum)
        let sign_id = a:existing_signs.max_id + 1
        let a:existing_signs.max_id = sign_id
        exe 'sign place '.sign_id.' line='.a:entry.lnum.
                                \ ' name='.type.
                                \ ' buffer='.a:entry.bufnr
        let b:neomake_signs[a:entry.lnum] = sign_id
    elseif type ==# 'neomake_err'
        " Upgrade this sign to an error
        exe 'sign place '.b:neomake_signs[a:entry.lnum].' name='.type.
                                                      \ ' buffer='.a:entry.bufnr
    endif

    " Replace all existing signs for this line, so that ours appear on top
    for existing in get(l:signs.by_line, a:entry.lnum, [])
        if existing.name !~# 'neomake_'
            exe 'sign unplace '.existing.id.' buffer='.a:entry.bufnr
            exe 'sign place '.existing.id.' line='.existing.line.
                                        \ ' name='.existing.name.
                                        \ ' buffer='.a:entry.bufnr
        endif
    endfor
endfunction

" This command intentionally ends with a space
exe 'sign define neomake_invisible text=\ '

function! neomake#signs#RedefineSign(name, opts)
    let signs = neomake#signs#GetSigns({'name': a:name})
    for lnum in keys(signs.by_line)
        for sign in signs.by_line[lnum]
            exe 'sign place '.sign.id.' name=neomake_invisible file='.sign.file
        endfor
    endfor

    let sign_define = 'sign define '.a:name
    for attr in keys(a:opts)
        let sign_define .= ' '.attr.'='.a:opts[attr]
    endfor
    exe sign_define

    for lnum in keys(signs.by_line)
        for sign in signs.by_line[lnum]
            exe 'sign place '.sign.id.' name='.a:name.' file='.sign.file
        endfor
    endfor
endfunction

function! neomake#signs#RedefineErrorSign(...)
    let default_opts = {'text': '✖'}
    let opts = {}
    if a:0
        call extend(opts, a:1)
    elseif exists('g:neomake_error_sign')
        call extend(opts, g:neomake_error_sign)
    endif
    call extend(opts, default_opts, 'keep')
    call neomake#signs#RedefineSign('neomake_err', opts)
endfunction

function! neomake#signs#RedefineWarningSign(...)
    let default_opts = {'text': '⚠'}
    let opts = {}
    if a:0
        call extend(opts, a:1)
    elseif exists('g:neomake_warning_sign')
        call extend(opts, g:neomake_warning_sign)
    endif
    call extend(opts, default_opts, 'keep')
    call neomake#signs#RedefineSign('neomake_warn', opts)
endfunction

let s:signs_defined = 0
function! neomake#signs#DefineSigns()
    if !s:signs_defined
        let s:signs_defined = 1
        call neomake#signs#RedefineErrorSign()
        call neomake#signs#RedefineWarningSign()
    endif
endfunction
