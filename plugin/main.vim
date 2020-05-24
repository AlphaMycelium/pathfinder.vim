if !exists('g:pf_motions')
  let g:pf_motions = [
    \ {'motion': 'j', 'weight': 1},
    \ {'motion': 'k', 'weight': 1},
    \ {'motion': '(', 'weight': 1},
    \ {'motion': ')', 'weight': 1},
    \ {'motion': '{', 'weight': 1},
    \ {'motion': '}', 'weight': 1},
    \ {'motion': '#', 'weight': 1},
    \ {'motion': '*', 'weight': 1},
    \ {'motion': ']m', 'weight': 1},
    \ {'motion': '[m', 'weight': 1}
    \ ]
  let g:pf_motions_target_line_only = [
    \ {'motion': '0', 'weight': 1},
    \ {'motion': '^', 'weight': 1},
    \ {'motion': '$', 'weight': 1},
    \ {'motion': 'g_', 'weight': 1},
    \ {'motion': '%', 'weight': 1},
    \ {'motion': 'h', 'weight': 1},
    \ {'motion': 'l', 'weight': 1},
    \ {'motion': 'w', 'weight': 1},
    \ {'motion': 'e', 'weight': 1},
    \ {'motion': 'b', 'weight': 1},
    \ {'motion': 'ge', 'weight': 1},
    \ {'motion': 'W', 'weight': 1},
    \ {'motion': 'E', 'weight': 1},
    \ {'motion': 'B', 'weight': 1},
    \ {'motion': 'gE', 'weight': 1},
    \ ]
endif
if !exists('g:pf_heuristic_strength')
  let g:pf_heuristic_strength = 0.1
endif


function! PathfinderBegin()
  " Record the current cursor position
  let g:pf_start_line = line('.')
  let g:pf_start_col = col('.')
endfunction
command PathfinderBegin call PathfinderBegin()


function! MinF(open_nodes)
  let min_node = values(a:open_nodes)[0]
  for [key, node] in items(a:open_nodes)[1:]
    if node.f < min_node.f
      let min_node = node
    endif
  endfor
  return min_node
endfunction

function! CoordString(l, c)
  return a:l . ',' . a:c
endfunction

function! CreateNode(l, c, rb, rw, rf)
  let key = CoordString(a:l, a:c)
  return {'key': key, 'line': a:l, 'col': a:c,
    \ 'reached_by': a:rb, 'reached_weight': a:rw, 'reached_from': a:rf}
endfunction

function! DoMotion(node, child_nodes, motion)
  " Move to this node's character, then run the movement
  try
    execute 'silent! normal! ' . a:node['line'] . 'G' . a:node['col'] . '|' . a:motion['motion']
  catch
    " Ignore motions which cause an error
    return
  endtry

  if line('.') != a:node['line'] || col('.') != a:node['col']
    " Only add the child node if the motion had an effect
    " This means we don't add things such as l at the end of a line
    call add(a:child_nodes, CreateNode(
      \ line('.'), col('.'), a:motion['motion'], a:motion['weight'], a:node))
  endif
endfunction

function! GetChildNodes(node)
  let child_nodes = []

  for motion in g:pf_motions
    call DoMotion(a:node, child_nodes, motion)
  endfor

  " If we are on the same line as the target position, use these too
  if line('.') == g:pf_end_line
    for motion in g:pf_motions_target_line_only
      call DoMotion(a:node, child_nodes, motion)
    endfor
  endif

  return child_nodes
endfunction

function! Backtrack(final_node)
  let node = a:final_node
  let motion_sequence = []
  while node.f > 0
    call add(motion_sequence, node.reached_by)
    let node = node.reached_from
  endwhile

  call reverse(motion_sequence)
  echom motion_sequence
endfunction

function! PathfinderRun()
  if !exists('g:pf_start_line') || !exists('g:pf_start_col')
    echom 'Please run :PathfinderBegin to set a start position first'
    return
  endif

  let g:pf_end_line = line('.')
  let g:pf_end_col = col('.')

  let open_nodes = {}
  let closed_nodes = {}

  let start_node = CreateNode(g:pf_start_line, g:pf_start_col, '', 0, 0)
  let start_node.g = 0
  let start_node.f = 0
  let open_nodes[start_node.key] = start_node

  while len(open_nodes) > 0
    let current_node = MinF(open_nodes)
    unlet open_nodes[current_node['key']]
    let closed_nodes[current_node['key']] = current_node

    if current_node.line == g:pf_end_line && current_node.col == g:pf_end_col
      " Found the target
      return Backtrack(current_node)
    endif

    for child_node in GetChildNodes(current_node)
      if has_key(closed_nodes, child_node.key) | continue | endif

      let child_node.g = current_node.g + child_node.reached_weight
      let h = abs(g:pf_end_line - child_node.line) + abs(g:pf_end_col - child_node.col)
      let child_node.f = child_node.g + (h * g:pf_heuristic_strength)

      if has_key(open_nodes, child_node.key)
	" Replace the existing node if this one has a lower g
	if child_node.g < open_nodes[child_node.key].g
	  let open_nodes[child_node.key] = child_node
	endif
      else
	let open_nodes[child_node.key] = child_node
      endif
    endfor
  endwhile
endfunction
command PathfinderRun call PathfinderRun()
