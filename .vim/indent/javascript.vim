" Vim indent file
" Language: Javascript
" Maintainer: Chris Paul ( https://github.com/bounceme )
" URL: https://github.com/pangloss/vim-javascript
" Last Change: December 26, 2016

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetJavascriptIndent()
setlocal autoindent nolisp nosmartindent
setlocal indentkeys+=0],0)

let b:undo_indent = 'setlocal indentexpr< smartindent< autoindent< indentkeys<'

" Only define the function once.
if exists('*GetJavascriptIndent')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Get shiftwidth value
if exists('*shiftwidth')
  function s:sw()
    return shiftwidth()
  endfunction
else
  function s:sw()
    return &sw
  endfunction
endif

" searchpair() wrapper
if has('reltime')
  function s:GetPair(start,end,flags,skip,time,...)
    return searchpair(a:start,'',a:end,a:flags,a:skip,max([prevnonblank(v:lnum) - 2000,0] + a:000),a:time)
  endfunction
else
  function s:GetPair(start,end,flags,skip,...)
    return searchpair(a:start,'',a:end,a:flags,a:skip,max([prevnonblank(v:lnum) - 1000,get(a:000,1)]))
  endfunction
endif

" Regex of syntax group names that are or delimit string or are comments.
let s:syng_strcom = 'string\|comment\|regex\|special\|doc\|template'
let s:syng_str = 'string\|template'
let s:syng_com = 'comment\|doc'
" Expression used to check whether we should skip a match with searchpair().
let s:skip_expr = "synIDattr(synID(line('.'),col('.'),0),'name') =~? '".s:syng_strcom."'"

function s:skip_func()
  if !s:free || search('`\|\*\/','nW',s:looksyn)
    let s:free = !eval(s:skip_expr)
    let s:looksyn = s:free ? line('.') : s:looksyn
    return !s:free
  endif
  let s:looksyn = line('.')
  return (search('\/','nbW',s:looksyn) || search('[''"\\]','nW',s:looksyn)) && eval(s:skip_expr)
endfunction

function s:alternatePair(stop)
  while search('[][(){}]','bW',a:stop)
    if !s:skip_func()
      let idx = stridx('])}',s:looking_at())
      if idx + 1
        if !s:GetPair(['\[','(','{'][idx], '])}'[idx],'bW','s:skip_func()',2000,a:stop)
          break
        endif
      else
        return
      endif
    endif
  endwhile
  call cursor(v:lnum,1)
endfunction

function s:save_pos(f,...)
  let l:pos = getpos('.')[1:2]
  let ret = call(a:f,a:000)
  call call('cursor',l:pos)
  return ret
endfunction

function s:syn_at(l,c)
  return synIDattr(synID(a:l,a:c,0),'name')
endfunction

function s:looking_at()
  return getline('.')[col('.')-1]
endfunction

function s:token()
  return s:looking_at() =~ '\k' ? expand('<cword>') : s:looking_at()
endfunction

function s:previous_token()
  let ln = line('.')
  let token = ''
  while search('.\>\|[^[:alnum:][:space:]_$]','bW')
    if (s:looking_at() == '/' || line('.') != ln && search('\/\/','nbW',
          \ line('.'))) && s:syn_at(line('.'),col('.')) =~? s:syng_com
      call search('\_[^/]\zs\/[/*]','bW')
    else
      let token = s:token()
      break
    endif
  endwhile
  return token
endfunction

" switch case label pattern
let s:case_stmt = '\<\%(case\>\s*[^ \t:].*\|default\s*\):\C'

function s:jump_label(ln,con)
  if !cursor(a:ln,match(' '.a:con, ':$'))
    let id = s:previous_token()
    if id =~ '\k' && s:IsBlock()
      return id ==# 'default' ? 2 : 1
    endif
  endif
endfunction

" configurable regexes that define continuation lines, not including (, {, or [.
let s:opfirst = '^' . get(g:,'javascript_opfirst',
      \ '\%([<>=,?^%|*/&]\|\([-.:+]\)\1\@!\|!=\|in\%(stanceof\)\=\>\)')
let s:continuation = get(g:,'javascript_continuation',
      \ '\%([<=,.~!?/*^%|&:]\|+\@<!+\|-\@<!-\|=\@<!>\|\<\%(typeof\|delete\|void\|in\|instanceof\)\)') . '$'

function s:continues(ln,con)
  return !cursor(a:ln, match(' '.a:con,s:continuation)) &&
        \ eval((['s:syn_at(line("."),col(".")) !~? "regex"'] +
        \ repeat(['s:previous_token() != "."'],5) + [1])[
        \ index(split('/ typeof in instanceof void delete'),s:token())])
endfunction

" get the line of code stripped of comments. if called with two args, leave
" cursor at the last non-comment char.
function s:Trim(ln,...)
  let pline = substitute(getline(a:ln),'\s*$','','')
  let l:max = max([match(pline,'.*[^/]\zs\/[/*]'),0])
  while l:max && s:syn_at(a:ln, strlen(pline)) =~? s:syng_com
    let pline = substitute(strpart(pline, 0, l:max),'\s*$','','')
    let l:max = max([match(pline,'.*[^/]\zs\/[/*]'),0])
  endwhile
  return !a:0 || cursor(a:ln,strlen(pline)) ? pline : pline
endfunction

" Find line above 'lnum' that isn't empty or in a comment
function s:PrevCodeLine(lnum)
  let l:n = prevnonblank(a:lnum)
  while l:n
    if getline(l:n) =~ '^\s*\%(\/[/*]\|-->\|<!--\|#\)' 
      if (stridx(getline(l:n),'`') > 0 || getline(l:n-1)[-1:] == '\') &&
            \ s:syn_at(l:n,1) =~? s:syng_str
        return l:n
      endif
      let l:n = prevnonblank(l:n-1)
    elseif s:syn_at(l:n,1) =~? s:syng_com
      let l:n = search('\/\*\%<' . l:n . 'l','nbW')
    else
      return l:n
    endif
  endwhile
endfunction

" Check if line 'lnum' has a balanced amount of parentheses.
function s:Balanced(lnum)
  let l:open = 0
  let l:line = getline(a:lnum)
  let pos = match(l:line, '[][(){}]', 0)
  while pos != -1
    if s:syn_at(a:lnum,pos + 1) !~? s:syng_strcom
      let l:open += match(' ' . l:line[pos],'[[({]')
      if l:open < 0
        return
      endif
    endif
    let pos = match(l:line, '[][(){}]', pos + 1)
  endwhile
  return !l:open
endfunction

function s:OneScope(lnum)
  let pline = s:Trim(a:lnum,1)
  let kw = 'else do'
  if pline[-1:] == ')' && s:GetPair('(', ')', 'bW', s:skip_expr, 100) > 0
    call s:previous_token()
    let kw = 'for if let while with'
    if index(split('await each'),s:token()) + 1
      call s:previous_token()
      let kw = 'for'
    endif
  endif
  return pline[-2:] == '=>' || index(split(kw),s:token()) + 1 &&
        \ s:save_pos('s:previous_token') != '.'
endfunction

" returns braceless levels started by 'i' and above lines * &sw. 'num' is the
" lineNr which encloses the entire context, 'cont' if whether line 'i' + 1 is
" a continued expression, which could have started in a braceless context
function s:iscontOne(i,num,cont)
  call cursor(v:lnum,1) " normalize pos
  let [l:i, l:num, bL] = [a:i, a:num + !a:num, 0]
  let pind = a:num ? indent(l:num) + s:W : 0
  let ind = indent(l:i) + (a:cont ? 0 : s:W)
  while l:i >= l:num && (ind > pind || l:i == l:num)
    if indent(l:i) < ind && s:OneScope(l:i)
      let bL += s:W
      let l:i = line('.')
    elseif !a:cont || bL || ind < indent(a:i)
      break
    endif
    let ind = min([ind, indent(l:i)])
    let l:i = s:PrevCodeLine(l:i - 1)
  endwhile
  return bL
endfunction

" https://github.com/sweet-js/sweet.js/wiki/design#give-lookbehind-to-the-reader
function s:IsBlock()
  let l:ln = line('.')
  let char = s:previous_token()
  let syn = char =~ '[{>/]' ? s:syn_at(line('.'),col('.')-(char == '{')) : ''
  if syn =~? 'xml\|jsx'
    return char != '{'
  elseif char =~ '\k'
    return index(split('return const let import export yield default delete var void typeof throw new in instanceof')
          \ ,char) < (line('.') != l:ln) || s:previous_token() == '.'
  elseif char == '>'
    return getline('.')[col('.')-2] == '=' || syn =~? '^jsflow'
  elseif char == ':'
    let lp = strpart(getline('.'),0,col('.'))
    return lp =~# '\<case\>\s*[^ \t:].*:$' || s:jump_label(line('.'),lp) &&
          \ (s:looking_at() != '{' || s:IsBlock())
  endif
  return syn =~? 'regex' || char !~ '[-=~!<*+,/?^%|&([]'
endfunction

function GetJavascriptIndent()
  let b:js_cache = get(b:,'js_cache',[0,0,0])
  " Get the current line.
  call cursor(v:lnum,1)
  let l:line = getline('.')
  let syns = s:syn_at(v:lnum, 1)

  " start with strings,comments,etc.
  if syns =~? s:syng_com
    if l:line =~ '^\s*\*'
      return cindent(v:lnum)
    elseif l:line !~ '^\s*\/[/*]'
      return -1
    endif
  elseif syns =~? s:syng_str && l:line !~ '^[''"]'
    if b:js_cache[0] == v:lnum - 1 && s:Balanced(v:lnum-1)
      let b:js_cache[0] = v:lnum
    endif
    return -1
  endif
  let l:lnum = s:PrevCodeLine(v:lnum - 1)
  if !l:lnum
    return
  endif

  let l:line = substitute(l:line,'^\s*','','')
  if l:line[:1] == '/*'
    let l:line = substitute(l:line,'^\%(\/\*.\{-}\*\/\s*\)*','','')
  endif
  if l:line =~ '^\%(\/[/*]\|-->\|<!--\|#\)'
    let l:line = ''
  endif

  " the containing paren, bracket, or curly. Many hacks for performance
  let idx = strlen(l:line) ? stridx('])}',l:line[0]) : -1
  if b:js_cache[0] >= l:lnum && b:js_cache[0] < v:lnum &&
        \ (b:js_cache[0] > l:lnum || s:Balanced(l:lnum))
    call call('cursor',b:js_cache[1:])
  else
    let [s:looksyn, s:free, top] = [v:lnum - 1, 1, (!indent(l:lnum) &&
          \ s:syn_at(l:lnum,1) !~? s:syng_str) * l:lnum]
    if idx + 1
      call s:GetPair(['\[','(','{'][idx], '])}'[idx],'bW','s:skip_func()',2000,top)
    elseif indent(v:lnum) && syns =~? 'block'
      call s:GetPair('{','}','bW','s:skip_func()',2000,top)
    else
      call s:alternatePair(top)
    endif
  endif

  if idx + 1
    if idx == 2 && search('\S','bW',line('.')) && s:looking_at() == ')'
      call s:GetPair('(',')','bW',s:skip_expr,200)
    endif
    return indent('.')
  endif

  let b:js_cache = [v:lnum] + (line('.') == v:lnum ? [0,0] : getpos('.')[1:2])
  let num = b:js_cache[1]

  let [s:W, isOp, bL, switch_offset] = [s:sw(),0,0,0]
  if !num || s:looking_at() == '{' && s:IsBlock()
    let pline = s:Trim(l:lnum)
    let label = s:save_pos('s:jump_label',l:lnum,pline)
    if num && s:looking_at() == ')' && s:GetPair('(', ')', 'bW', s:skip_expr, 100) > 0
      let num = line('.')
      if s:previous_token() ==# 'switch' && s:previous_token() != '.'
        if &cino !~ ':' || !has('float')
          let switch_offset = s:W
        else
          let cinc = matchlist(&cino,'.*:\(-\)\=\([0-9.]*\)\(s\)\=\C')
          let switch_offset = float2nr(str2float(cinc[1].(strlen(cinc[2]) ? cinc[2] : strlen(cinc[3])))
                \ * (strlen(cinc[3]) ? s:W : 1))
        endif
        if pline[-1:] != '.' && l:line =~# '^' . s:case_stmt
          return indent(num) + switch_offset
        elseif label == 2 || pline =~# '\<case\>\s*[^ \t:].*:$'
          return indent(l:lnum) + s:W
        endif
      endif
    endif
    if !label && pline[-1:] !~ '[{;]'
      let isOp = l:line =~# s:opfirst || s:continues(l:lnum,pline)
      let bL = s:iscontOne(l:lnum,num,isOp)
      let bL -= (bL && l:line[0] == '{') * s:W
    endif
  endif

  " main return
  if isOp
    return (num ? indent(num) : -s:W) + (s:W * 2) + switch_offset + bL
  elseif num
    return indent(num) + s:W + switch_offset + bL
  endif
  return bL
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
