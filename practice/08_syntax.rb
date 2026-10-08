# frozen_string_literal: true

# 08. Live syntax errors. `:e!` undoes.

# 1. The `def` below does not close its parenthesis. With the file broken,
#    only `Lint/Syntax` shows up. To fix it, cursor on `b`, `a`, `)`, `<Esc>`,
#    and the error goes away without saving.
def add(a, b
  a + b
end

# 2. Break it another way. On the `end` line above, `dd`. Watch the message
#    change with `<C-w>d`, then `u`.
puts add(1, 2)
