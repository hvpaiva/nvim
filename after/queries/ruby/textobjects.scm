; extends

; Conditionals and loops for mini.ai's `o`, and the body of an endless def for
; `F`. Inner objects capture each statement of the body (mini.ai spans from the
; first to the last), since `then`/`do` nodes start on the header line and
; `do` includes the `end`.

(method "=" body: (_) @function.inner)
(singleton_method "=" body: (_) @function.inner)

[(if) (unless) (case) (if_modifier) (unless_modifier)] @conditional.outer
(_ consequence: (then (_)+ @conditional.inner))
(_ alternative: (else (_)+ @conditional.inner))
(when body: (then (_)+ @conditional.inner))
(case (else (_)+ @conditional.inner))
[(if_modifier body: (_) @conditional.inner) (unless_modifier body: (_) @conditional.inner)]

[(while) (until) (for) (while_modifier) (until_modifier)] @loop.outer
(_ body: (do (_)+ @loop.inner))
[(while_modifier body: (_) @loop.inner) (until_modifier body: (_) @loop.inner)]
