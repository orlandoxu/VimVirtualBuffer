" Settings
" 1. g:vvb_ignore_files
"     default as ['NERD_tree', 'quickfix']
" 2. g:vvb_new_buffer_mode
"     tail / head / next
"     default as next.

if !exists('g:vvb_ignore_files')
  let g:vvb_ignore_files = ['NERD_tree']
endif

if !exists('g:vvb_ignore_buffer_types')
  let g:vvb_ignore_buffer_types = ["terminal", "quickfix", "nofile", "nowrite"]
endif

" filetype missing, case filetype may be async!!!
" if !exists('g:vvb_ignore_file_types')
"   let g:vvb_ignore_file_types = ["fugitive"]
" endif

" New buffer mode
" tail / head / next
let s:vvb_new_buffer_mode = "tail"
" type => [bufnr, filename, filepath, buftype, isModified]
" like => [[2, 'init.vim', 'path', 'buftype', 'isModified'], [3, 'this.js', 'path', 'buftype', 'isModified']]
let s:bufferSortedList = []
" First buffer using position = 1
let s:buf_position = 0

" Need reset buffer's meta!!
" Case some meta is async!!
function! s:resetBufferModified()
  for i in s:bufferSortedList
    let i[4] = getbufvar(i[0], '&mod')
  endfor
endfunction

function! RenderBufferTab()
  let render = ""
  let position = 1
  call s:resetBufferModified()
  " echo s:bufferSortedList

  " for i in range(len(elements) - 2, 0)
  for i in s:bufferSortedList
    let hl = "%#BuffetBuffer#"
    if s:buf_position == position
      let hl = "%#BuffetCurrentBuffer#"
    endif

    let isModified = ''
    if i[4]
      let isModified = '+'
    endif

    let render = render . hl . ' ' . i[1] . isModified . hl . ' ' . '%T'
    let position = position + 1
  endfor

  return render . '%#BuffetBuffer#'
endfunction

" Ignore files with type & name
function! s:isIgnoredBufType(bufMeta)
  " Step 1. check buffer type
  if index(g:vvb_ignore_buffer_types, a:bufMeta[3]) >= 0
    return 1
  endif

  " if index(g:vvb_ignore_file_types, a:bufMeta[5]) >= 0
  "   return 1
  " endif

  " Step 2. check ignore with filename
  for i in g:vvb_ignore_files
    if a:bufMeta[1] =~? i
      return 1
    endif
  endfor

  return 0
endfunction

" Get the window's width
" TODO: manage buffer's width far beyond window width
function! s:getWindowWidth() abort
  return &columns
endfunction

" Get buffer meta
" return => [bufnr, filename, filepath, buftype, isModified]
function s:getBufferMeta(bufNr)
  let filepath = bufname(a:bufNr)
  let strArr = split(filepath, '/')
  if len(strArr) == 0
    return [a:bufNr, '*', '', getbufvar(a:bufNr, '&buftype', ''), getbufvar(a:bufNr, '&mod')]
  endif

  " [filename, filepath]
  return [a:bufNr, strArr[len(strArr) - 1],  filepath, getbufvar(a:bufNr, '&buftype', ''), getbufvar(a:bufNr, '&mod')]
endfunction

" Init bufferList
function! s:getAllBuffers()
  " like [3, 4, 5] 
  let allBuffers = filter(range(1, bufnr('$')), 'buflisted(v:val)')

  let bufferList = []
  for i in allBuffers
    let bufferMeta = s:getBufferMeta(i)
    call add(bufferList, bufferMeta)
  endfor

  " [[2, 'init.vim', 'User/d/init.vim'], [3, 'this.js', '/']]
  return allBuffers
endfunction

" Check if has already managed
" Return searched buffer's position
function! s:checkIfAlreadyManaged(bufNr)
  let position = 0
  for i in s:bufferSortedList
    let position = position + 1
    if i[0] == a:bufNr
      return position
    endif
  endfor

  " return 0 if have not managed
  return 0
endfunction

" Add buffer to list(no need to check if is exists)
" bufMeta => [bufnr, filename, filepath, buftype, isModified]
" return => new buffer's position(just return, no modified)
function! s:addBufToSortedList(bufMeta)
  " 如果存在就不添加
  " echom('burNr:' . a:bufNr)
  let position = s:checkIfAlreadyManaged(a:bufMeta[0])
  " echom('position:' . position)
  if position
    return position
  endif

  " three model (tail / next / head)
  if s:vvb_new_buffer_mode == 'tail'
    call add(s:bufferSortedList, a:bufMeta)
    let position = len(s:bufferSortedList)
  elseif s:vvb_new_buffer_mode == 'next'
    call insert(s:bufferSortedList, a:bufMeta, s:buf_position)
    let position = s:buf_position + 1
  else
    call insert(s:bufferSortedList, a:bufMeta)
    let position = 1
  end

  return position
endfunction

" return => [position, [...bufMata]]
" return => [] if none
function! s:delBufToSortedList(bufNr)
  let idx = 0
  for i in s:bufferSortedList
    if a:bufNr == i[0]
      call remove(s:bufferSortedList, idx)
      return [idx + 1, i]
    endif

    let idx = idx + 1
  endfor

  return []
endfunction

" remove a buffer from list
function! s:BufDeleteEvent()
  let bufMeta = s:delBufToSortedList(str2nr(expand('<abuf>')))

  " return if not managed
  if !len(bufMeta)
    return
  endif

  " remove left buffer, move buf_position left
  if bufMeta[0] < s:buf_position
    let s:buf_position = s:buf_position - 1
  end

  " call s:render()
endfunction

function! s:BufEnterEvent(bufNr)
  let position = 0
  for i in s:bufferSortedList
    let position = position + 1

    if i[0] == a:bufNr
      let s:buf_position = position
      break
    endif
  endfor
endfunction

function! s:BufLeaveEvent()
  let leaveBufNr = str2nr(expand('<abuf>'))
  let s:buf_position = 0
endfunction

function! VimEnterEvent()
  let leaveBufNr = str2nr(expand('<abuf>'))
  let s:buf_position = 0

  " call s:getAllBuffers()
  call s:changeBufferMode2UserSetting()

  " position 放在当前buffer
  let currBufnr = bufnr('%')
  let position = 0
  for i in s:bufferSortedList
    let position = position + 1
    if i[0] == currBufnr
      let s:buf_position = position
      return
    endif
  endfor
endfunction

" Set buffer open mode 1s latter
" to support vim-workspace.vim
" function! ChangeBufferMode2UserSetting(timer)
function! s:changeBufferMode2UserSetting()
  let s:vvb_new_buffer_mode = get(g:, "vvb_new_buffer_mode", "next")
endfunction

function! s:BufAddEvent(bufNr)
  let buffmeta = s:getBufferMeta(a:bufNr)

  " ignore buffer
  if s:isIgnoredBufType(buffmeta)
    return
  endif

  " just add to list, don't modified the tab position
  call s:addBufToSortedList(buffmeta)

  " render new buffer
  " call s:render()
endfunction

" Delete! We using check every time when rerender
" function! s:InsertChangeEvent(bufNr)
"   echom 'mdof:' . a:bufNr
"   let position = s:checkIfAlreadyManaged(a:bufNr)
"   if !position
"     return
"   endif
" 
"   let s:bufferSortedList[position][4] = getbufvar(a:bufNr, '&mod')
" endfunction


augroup vvb_binding_event
  autocmd!
  autocmd VimEnter * set showtabline=2
  " autocmd VimEnter,BufAdd,TabEnter * set showtabline=2
  autocmd VimEnter * :call VimEnterEvent()
  " no need to using timer, using VimEnter 
  " autocmd VimEnter * :call timer_start(1000, "ChangeBufferMode2UserSetting")
  autocmd BufEnter * :call s:BufEnterEvent(str2nr(expand("<abuf>")))
  autocmd BufAdd * :call s:BufAddEvent(str2nr(expand("<abuf>")))
  autocmd BufDelete * :call s:BufDeleteEvent()
  autocmd BufLeave * :call s:BufLeaveEvent()
  " autocmd BufType * :call s:BufLeaveEvent()
  " autocmd InsertChange * :call s:InsertChangeEvent(str2nr(expand("<abuf>")))
augroup END

function! s:SetColors()
  hi! BuffetCurrentBuffer cterm=NONE ctermbg=246 ctermfg=0 guibg=#00F00 guifg=#000000
  hi! BuffetBuffer cterm=NONE ctermbg=237 ctermfg=244 guibg=#999999 guifg=#000000
endfunction

augroup buffet_set_colors
  autocmd!
  autocmd ColorScheme * call s:SetColors()
augroup end

" Set solors also at the startup
call s:SetColors()

set tabline=%!RenderBufferTab()

" Next buffer command
function! s:bufNext()
  let position = 0
  if len(s:bufferSortedList) > s:buf_position
    let position = s:buf_position + 1
  else
    let position = 1
  endif

  execute 'silent buffer' s:bufferSortedList[position - 1][0]
endfunction

function! s:bufPrev()
  let position = 0
  if s:buf_position > 1
    let position = s:buf_position - 1
  else
    let position = len(s:bufferSortedList)
  endif

  execute 'silent buffer' s:bufferSortedList[position - 1][0]
endfunction

function! s:moveBufLeft()
  if s:buf_position <= 1
    return
  endif

  let tmp = s:bufferSortedList[s:buf_position - 1]
  let s:bufferSortedList[s:buf_position - 1] = s:bufferSortedList[s:buf_position - 2]
  let s:bufferSortedList[s:buf_position - 2] = tmp

  let s:buf_position = s:buf_position - 1
  :redrawtabline
endfunction

function! s:moveBufRight()
  if s:buf_position >= len(s:bufferSortedList)
    return
  endif

  let tmp = s:bufferSortedList[s:buf_position - 1]
  let s:bufferSortedList[s:buf_position - 1] = s:bufferSortedList[s:buf_position]
  let s:bufferSortedList[s:buf_position] = tmp

  let s:buf_position = s:buf_position + 1
  :redrawtabline
endfunction


command! BufNext call s:bufNext()
command! BufPrev call s:bufPrev()
command! MoveBufLeft call s:moveBufLeft()
command! MoveBufRight call s:moveBufRight()
